//
// Copyright 2009-2010 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "extThree20CSSStyle/TTCSSStyleSheet.h"

#import "extThree20CSSStyle/TTCSSParser.h"

// Style
#import "Three20Style/TTGlobalStyle.h"
#import "Three20Style/TTStyle.h"

// Core
#import "Three20Core/TTCorePreprocessorMacros.h"
#import "Three20Core/TTGlobalCore.h"
#import "Three20Core/TTDebug.h"

NSString* kCssPropertyColor           = @"color";
NSString* kCssPropertyBackgroundColor = @"background-color";
NSString* kCssPropertyFont            = @"font";
NSString* kCssPropertyFontSize        = @"font-size";
NSString* kCssPropertyFontWeight      = @"font-weight";
NSString* kCssPropertyFontFamily      = @"font-family";
NSString* kCssPropertyTextShadow      = @"text-shadow";

// Text shadow keys
NSString* kKeyTextShadowHOffset = @"hoffset";
NSString* kKeyTextShadowVOffset = @"voffset";
NSString* kKeyTextShadowBlur    = @"blur";
NSString* kKeyTextShadowColor   = @"color";


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TTCSSStyleSheet


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init {
  if (self = [super init]) {
    [[NSNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(didReceiveMemoryWarning:)
     name: UIApplicationDidReceiveMemoryWarningNotification
     object: nil];
  }

  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
   removeObserver: self
   name: UIApplicationDidReceiveMemoryWarningNotification
   object: nil];

  TT_RELEASE_SAFELY(_cssStyles);
  TT_RELEASE_SAFELY(_cachedCssStyles);
  TT_RELEASE_SAFELY(_colorLookupTable);
  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSNotifications


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)didReceiveMemoryWarning:(void*)object {
  [self freeMemory];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark CSS Parsing


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)loadFromFilename:(NSString*)filename {
  TT_RELEASE_SAFELY(_cssStyles);
  TT_RELEASE_SAFELY(_cachedCssStyles);

  BOOL didLoadSuccessfully = NO;

  if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
    TTCSSParser* parser = [[TTCSSParser alloc] init];

    NSDictionary* results = [parser parseFilename:filename];
    TT_RELEASE_SAFELY(parser);

    _cssStyles = [results retain];
    _cachedCssStyles = [[NSMutableDictionary alloc] initWithCapacity:[_cssStyles count]];

    didLoadSuccessfully = YES;
  }

  return didLoadSuccessfully;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Object Cache


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)objectForCssSelector:(NSString*)selector propertyName:(NSString*)propertyName {
  NSDictionary* ruleSet = [_cachedCssStyles objectForKey:selector];
  if (nil != ruleSet) {
    return [ruleSet objectForKey:propertyName];
  }

  return nil;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setObjectForCssSelector: (NSString*)selector
                   propertyName: (NSString*)propertyName
                         object: (id)object {
  TTDASSERT(TTIsStringWithAnyText(selector));
  NSMutableDictionary* ruleSet = [_cachedCssStyles objectForKey:selector];
  if (nil == ruleSet) {
    ruleSet = [[NSMutableDictionary alloc] init];
    [_cachedCssStyles setObject:ruleSet forKey:selector];

    // Can release here because it's now being retained by _processedCssStyles
    [ruleSet release];
  }

  [ruleSet setObject:object forKey:propertyName];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Colors


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSDictionary*)colorLookupTable {
  if (nil == _colorLookupTable) {
    // From the W3C HTML4 spec for colors:
    // http://www.w3.org/TR/css3-color/
    _colorLookupTable = [[NSDictionary alloc] initWithObjectsAndKeys:
                         RGBCOLOR(0x00, 0xFF, 0xFF), @"aqua",
                         [UIColor blackColor], @"black",
                         RGBCOLOR(0x00, 0x00, 0xFF), @"blue",
                         RGBCOLOR(0xFF, 0x00, 0xFF), @"fuschia",
                         RGBCOLOR(0x80, 0x80, 0x80), @"gray",
                         RGBCOLOR(0x00, 0x80, 0x00), @"green",
                         RGBCOLOR(0x00, 0xFF, 0x00), @"lime",
                         RGBCOLOR(0x80, 0x00, 0x00), @"maroon",
                         RGBCOLOR(0x00, 0x00, 0x80), @"navy",
                         RGBCOLOR(0x80, 0x80, 0x00), @"olive",
                         RGBCOLOR(0xFF, 0x00, 0x00), @"red",
                         RGBCOLOR(0x80, 0x00, 0x80), @"purple",
                         RGBCOLOR(0xC0, 0xC0, 0xC0), @"silver",
                         RGBCOLOR(0x00, 0x80, 0x80), @"teal",
                         RGBACOLOR(0xFF, 0xFF, 0xFF, 0x00), @"transparent",
                         [UIColor whiteColor], @"white",
                         RGBCOLOR(0xFF, 0xFF, 0x00), @"yellow",
                         nil];
  }

  return _colorLookupTable;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIColor*)colorFromCssString:(NSString*)cssString {
  UIColor* color = nil;

  if ([cssString characterAtIndex:0] == '#') {
    unsigned long colorValue = 0;

    // #FFF
    if ([cssString length] == 4) {
      colorValue = strtol([cssString UTF8String] + 1, nil, 16);
      colorValue = ((colorValue & 0xF00) << 12) | ((colorValue & 0xF00) << 8)
                   | ((colorValue & 0xF0) << 8) | ((colorValue & 0xF0) << 4)
                   | ((colorValue & 0xF) << 4) | (colorValue & 0xF);

    // #FFFFFF
    } else if ([cssString length] == 7) {
      colorValue = strtol([cssString UTF8String] + 1, nil, 16);
    }

    color = RGBCOLOR(((colorValue & 0xFF0000) >> 16),
                     ((colorValue & 0xFF00) >> 8),
                     (colorValue & 0xFF));
  } else {
    color = [[self colorLookupTable] objectForKey:cssString];

  }

  return color;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIColor*)colorWithCssSelector: (NSString*)selector
                        forState: (UIControlState)state
                    propertyName: (NSString*)propertyName {
  UIColor* color = [self objectForCssSelector:selector propertyName:propertyName];

  // No cached value.
  if (nil == color) {
    NSDictionary* ruleSet = [_cssStyles objectForKey:selector];

    // The given selector actually exists in the CSS.
    if (nil != ruleSet) {
      NSArray* values = [ruleSet objectForKey:propertyName];

      // Anything more or less is unsupported, and therefore this property is ignored
      // according to the W3C guidelines.
      TTDASSERT([values count] == 1);
      if ([values count] == 1) {
        NSString* colorString = [values objectAtIndex:0];
        color = [self colorFromCssString:colorString];

        // And we can actually parse it.
        if (nil != color) {
          [self setObjectForCssSelector:selector propertyName:propertyName object:color];
        }
      }
    }
  }

  return color;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIColor*)colorWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  selector = [selector lowercaseString];

  return [self colorWithCssSelector:selector forState:state propertyName:kCssPropertyColor];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIColor*)backgroundColorWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  selector = [selector lowercaseString];

  return [self colorWithCssSelector: selector
                           forState: state
                       propertyName: kCssPropertyBackgroundColor];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Fonts


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIFont*)fontWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  selector = [selector lowercaseString];

  UIFont* font = [self objectForCssSelector:selector propertyName:kCssPropertyFont];

  // No cached value.
  if (nil == font) {
    NSDictionary* ruleSet = [_cssStyles objectForKey:selector];

    // The given selector actually exists in the CSS.
    if (nil != ruleSet) {
      CGFloat fontSize = [UIFont systemFontSize];
      BOOL isBold = NO;

      NSArray* fontSizeValues = [ruleSet objectForKey:kCssPropertyFontSize];
      // Anything more or less is unsupported, and therefore this property is ignored
      // according to the W3C guidelines.
      TTDASSERT([fontSizeValues count] == 1);
      if ([fontSizeValues count] == 1) {
        fontSize = [[fontSizeValues objectAtIndex:0] floatValue];
      }

      NSArray* fontWeightValues = [ruleSet objectForKey:kCssPropertyFontWeight];
      // Anything more or less is unsupported, and therefore this property is ignored
      // according to the W3C guidelines.
      if ([fontWeightValues count] == 1) {
        if ([[fontWeightValues objectAtIndex:0] isEqualToString:@"bold"]) {
          isBold = YES;
        }
      }

      NSArray* fontFamilyValues = [ruleSet objectForKey:kCssPropertyFontFamily];
      if ([fontFamilyValues count] > 0) {
        NSArray* systemFontFamilyNames = [UIFont familyNames];
        NSLog(@"Font families: %@", systemFontFamilyNames);
        for (NSString* fontName in fontFamilyValues) {
        }
        if ([[fontFamilyValues objectAtIndex:0] isEqualToString:@"bold"]) {
          isBold = YES;
        }
      }

      if (isBold) {
        font = [UIFont boldSystemFontOfSize:fontSize];

      } else {
        font = [UIFont systemFontOfSize:fontSize];
      }

      if (nil != font) {
        [self setObjectForCssSelector:selector propertyName:kCssPropertyFont object:font];
      }
    }
  }

  return font;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Text Shadows


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSDictionary*)textShadowWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  NSDictionary* textShadow = [self objectForCssSelector: selector
                                           propertyName: kCssPropertyTextShadow];

  // No cached value.
  if (nil == textShadow) {
    NSDictionary* ruleSet = [_cssStyles objectForKey:selector];

    // The given selector actually exists in the CSS.
    if (nil != ruleSet) {
      NSArray* values = [ruleSet objectForKey:kCssPropertyTextShadow];
      // Anything more or less is unsupported, and therefore this property is ignored
      // according to the W3C guidelines.
      TTDASSERT([values count] == 4);
      if ([values count] == 4) {
        NSNumber* horizOffset = [NSNumber numberWithFloat:[[values objectAtIndex:0] floatValue]];
        NSNumber* vertOffset  = [NSNumber numberWithFloat:[[values objectAtIndex:1] floatValue]];
        NSNumber* blurAmount  = [NSNumber numberWithFloat:[[values objectAtIndex:2] floatValue]];
        UIColor* color        = [self colorFromCssString:[values objectAtIndex:3]];

        textShadow = [[NSDictionary alloc] initWithObjectsAndKeys:
                      horizOffset, kKeyTextShadowHOffset,
                      vertOffset,  kKeyTextShadowVOffset,
                      blurAmount,  kKeyTextShadowBlur,
                      color,       kKeyTextShadowColor,
                      nil];
      }

      if (nil != textShadow) {
        [self setObjectForCssSelector: selector
                         propertyName: kCssPropertyTextShadow
                               object: textShadow];
      }
    }
  }

  return textShadow;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (UIColor*)textShadowColorWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  selector = [selector lowercaseString];

  NSDictionary* textShadow = [self textShadowWithCssSelector: selector
                                                    forState: state];
  return [textShadow objectForKey:kKeyTextShadowColor];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (CGSize)textShadowOffsetWithCssSelector:(NSString*)selector forState:(UIControlState)state {
  selector = [selector lowercaseString];

  NSDictionary* textShadow = [self textShadowWithCssSelector: selector
                                                    forState: state];
  return CGSizeMake([[textShadow objectForKey:kKeyTextShadowHOffset] floatValue],
                    [[textShadow objectForKey:kKeyTextShadowVOffset] floatValue]);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utilities


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)freeMemory {
  TT_RELEASE_SAFELY(_cachedCssStyles);
  TT_RELEASE_SAFELY(_colorLookupTable);
  _cachedCssStyles = [[NSMutableDictionary alloc] initWithCapacity:[_cssStyles count]];
}


@end

