/* Copyright (c) 2014 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GTLMapsEngineRastercollectionsListResponse.m
//

// ----------------------------------------------------------------------------
// NOTE: This file is generated from Google APIs Discovery Service.
// Service:
//   Google Maps Engine API (mapsengine/v1)
// Description:
//   The Google Maps Engine API allows developers to store and query geospatial
//   vector and raster data.
// Documentation:
//   https://developers.google.com/maps-engine/
// Classes:
//   GTLMapsEngineRastercollectionsListResponse (0 custom class methods, 2 custom properties)

#import "GTLMapsEngineRastercollectionsListResponse.h"

#import "GTLMapsEngineRasterCollection.h"

// ----------------------------------------------------------------------------
//
//   GTLMapsEngineRastercollectionsListResponse
//

@implementation GTLMapsEngineRastercollectionsListResponse
@dynamic nextPageToken, rasterCollections;

+ (NSDictionary *)arrayPropertyToClassMap {
  NSDictionary *map =
    [NSDictionary dictionaryWithObject:[GTLMapsEngineRasterCollection class]
                                forKey:@"rasterCollections"];
  return map;
}

@end
