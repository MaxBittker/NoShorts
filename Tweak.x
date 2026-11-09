// NoShorts: removes the Shorts tab and Shorts shelves/cells from YouTube.
// Nothing else. Filtering happens on the data model before layout, so no gaps.
// Feed filtering logic adapted from uYouEnhanced (Sources/uYouPlus.xm).

#import <objc/runtime.h>
#import <substrate.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTIItemSectionRenderer.h>
#import <YouTubeHeader/YTIItemSectionSupportedRenderers.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIHorizontalListRenderer.h>
#import <YouTubeHeader/YTIHorizontalListSupportedRenderers.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>

@interface YTPivotBarView : UIView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer;
@end

static BOOL isShortsDescription(NSString *d) {
    return [d containsString:@"shorts_shelf"] || [d containsString:@"shorts_video_cell"]
        // Single Shorts shown as regular video cards on Home (21.45+) carry this icon.
        || [d containsString:@"yt_fill_youtube_shorts_24pt"];
}

static BOOL isShortsSection(id section) {
    if ([section isKindOfClass:%c(YTIShelfRenderer)]) {
        NSArray *items = ((YTIShelfRenderer *)section).content.horizontalListRenderer.itemsArray;
        for (YTIHorizontalListSupportedRenderers *item in items) {
            if (isShortsDescription([item.elementRenderer description])) return YES;
        }
        return NO;
    }
    if ([section isKindOfClass:%c(YTIItemSectionRenderer)]) {
        YTIItemSectionRenderer *s = section;
        for (YTIItemSectionSupportedRenderers *item in s.contentsArray) {
            if (isShortsDescription([item.elementRenderer description])) return YES;
        }
        return isShortsDescription([s description]);
    }
    return NO;
}

#ifdef NOSHORTS_DEBUG
// Log each section's class, ELM component identifiers, and any "shorts" context.
static void debugLogSections(NSString *where, NSArray *sections) {
    static NSRegularExpression *eml;
    if (!eml) eml = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z0-9_\\-]+\\.eml" options:0 error:nil];
    NSLog(@"[NoShorts] %@: %lu sections", where, (unsigned long)sections.count);
    [sections enumerateObjectsUsingBlock:^(id s, NSUInteger i, BOOL *stop) {
        NSString *d = [s description];
        NSMutableOrderedSet *ids = [NSMutableOrderedSet orderedSet];
        for (NSTextCheckingResult *m in [eml matchesInString:d options:0 range:NSMakeRange(0, d.length)])
            [ids addObject:[d substringWithRange:m.range]];
        NSRange r = [d rangeOfString:@"shorts" options:NSCaseInsensitiveSearch];
        NSString *ctx = @"-";
        if (r.location != NSNotFound) {
            NSUInteger a = r.location > 80 ? r.location - 80 : 0;
            ctx = [[d substringWithRange:NSMakeRange(a, MIN((NSUInteger)200, d.length - a))]
                   stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        }
        NSLog(@"[NoShorts]  #%lu %@ filtered=%d len=%lu eml=%@ shorts=%@", (unsigned long)i,
              NSStringFromClass([s class]), isShortsSection(s), (unsigned long)d.length,
              [[ids array] componentsJoinedByString:@","], ctx);
    }];
}
#define DLOG_SECTIONS(w, s) debugLogSections(w, s)
#define DLOG(...) NSLog(@"[NoShorts] " __VA_ARGS__)
#else
#define DLOG_SECTIONS(w, s)
#define DLOG(...)
#endif

static NSMutableArray *withoutShorts(NSArray *sections) {
    NSMutableArray *out = [sections mutableCopy];
    [out removeObjectsAtIndexes:[out indexesOfObjectsPassingTest:^BOOL(id s, NSUInteger i, BOOL *stop) {
        return isShortsSection(s);
    }]];
    return out;
}

// Feeds, search, subscriptions, channel pages.
%hook YTInnerTubeCollectionViewController
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    @try {
        NSArray *sections = [self valueForKey:@"_sectionRenderers"];
        DLOG(@"displaySections on %@ (%@)", NSStringFromClass([self class]), NSStringFromClass([sections class]));
        if ([sections isKindOfClass:[NSArray class]]) {
            DLOG_SECTIONS(@"displaySections", sections);
            [self setValue:withoutShorts(sections) forKey:@"_sectionRenderers"];
        }
    } @catch (NSException *e) {}
    %orig;
}
- (void)addSectionsFromArray:(NSArray *)array {
    DLOG(@"addSections on %@", NSStringFromClass([self class]));
    DLOG_SECTIONS(@"addSections", array);
    %orig(array ? withoutShorts(array) : array);
}
%end

static BOOL isShortsTab(YTIPivotBarSupportedRenderers *item) {
    return [item.pivotBarItemRenderer.pivotIdentifier isEqualToString:@"FEshorts"]
        || [item.pivotBarIconOnlyItemRenderer.pivotIdentifier isEqualToString:@"FEshorts"];
}

// Data-level tab filter: whoever reads the tab bar's item list (old or new
// floating tab bar) never sees the Shorts item. Removal is idempotent.
static NSMutableArray *(*orig_pivotItemsArray)(id, SEL);
static NSMutableArray *hooked_pivotItemsArray(id self, SEL _cmd) {
    NSMutableArray *items = orig_pivotItemsArray(self, _cmd);
    if ([items isKindOfClass:[NSMutableArray class]]) {
        NSIndexSet *shorts = [items indexesOfObjectsPassingTest:^BOOL(id item, NSUInteger i, BOOL *stop) {
            return isShortsTab(item);
        }];
        if (shorts.count) {
            DLOG(@"pivot itemsArray: removing %lu of %lu", (unsigned long)shorts.count, (unsigned long)items.count);
            [items removeObjectsAtIndexes:shorts];
        }
    }
    return items;
}

#ifdef NOSHORTS_DEBUG
static void debugLogMethods(const char *name) {
    Class c = objc_getClass(name);
    if (!c) { DLOG(@"class %s: missing", name); return; }
    unsigned int n = 0;
    Method *m = class_copyMethodList(c, &n);
    NSMutableArray *sels = [NSMutableArray array];
    for (unsigned int i = 0; i < n; i++) [sels addObject:NSStringFromSelector(method_getName(m[i]))];
    free(m);
    DLOG(@"class %s methods: %@", name, [sels componentsJoinedByString:@" "]);
}
#endif

// Bottom tab bar.
%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSIndexSet *shorts = [items indexesOfObjectsPassingTest:^BOOL(YTIPivotBarSupportedRenderers *item, NSUInteger i, BOOL *stop) {
        return isShortsTab(item);
    }];
    DLOG(@"pivot bar: %lu items, removing %lu", (unsigned long)items.count, (unsigned long)shorts.count);
    [items removeObjectsAtIndexes:shorts];
    %orig;
}
%end

%ctor {
    DLOG(@"loaded into %@ (pivot=%d innertube=%d)", [[NSBundle mainBundle] bundleIdentifier],
         objc_getClass("YTPivotBarView") != nil, objc_getClass("YTInnerTubeCollectionViewController") != nil);
    // Protobuf accessors are added lazily; force resolution so there is a method to hook.
    Class renderer = objc_getClass("YTIPivotBarRenderer");
    if (renderer && [renderer instancesRespondToSelector:@selector(itemsArray)]) {
        MSHookMessageEx(renderer, @selector(itemsArray), (IMP)hooked_pivotItemsArray, (IMP *)&orig_pivotItemsArray);
        DLOG(@"hooked YTIPivotBarRenderer.itemsArray");
    }
#ifdef NOSHORTS_DEBUG
    const char *classes[] = {"YTPivotBarView", "YTFloatingPivotBarView", "YTAppPivotBarController",
                             "YTPivotBarViewController", "YTPivotBarItemView"};
    for (size_t i = 0; i < sizeof(classes) / sizeof(*classes); i++) debugLogMethods(classes[i]);
#endif
    %init;
}
