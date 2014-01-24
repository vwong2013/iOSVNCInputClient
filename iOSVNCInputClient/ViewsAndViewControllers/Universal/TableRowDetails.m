/*  
 Copyright 2013 V Wong <vwong122013 (at) gmail.com>
 Licensed under the Apache License, Version 2.0 (the "License"); you may not
 use this file except in compliance with the License. You may obtain a copy of
 the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 License for the specific language governing permissions and limitations under
 the License.
 */

#import "TableRowDetails.h"

@implementation TableRowDetails
-(id)init {
	return [self initWithCellId:nil Title:nil Subtitle:nil];
}

-(id)initWithCellId:(NSString *)cellId Title:(NSString *)title Subtitle:(NSString *)subtitle {
	if ((self = [super init])) {
		_cellId = cellId;
		_title = title;
		_subtitle = subtitle;
		_uitvcs = UITableViewCellStyleDefault;
		
		if (_subtitle)
			_uitvcs = UITableViewCellStyleSubtitle;
	}
	
	return self;
}
@end
