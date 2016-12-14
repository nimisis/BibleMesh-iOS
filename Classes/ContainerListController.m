//
//  ContainerListController.m
//  SDKLauncher-iOS
//
//  Created by Shane Meyer on 2/1/13.
//  Copyright (c) 2014 Readium Foundation and/or its licensees. All rights reserved.
//  
//  Redistribution and use in source and binary forms, with or without modification, 
//  are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice, this 
//  list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice, 
//  this list of conditions and the following disclaimer in the documentation and/or 
//  other materials provided with the distribution.
//  3. Neither the name of the organization nor the names of its contributors may be 
//  used to endorse or promote products derived from this software without specific 
//  prior written permission.
//  
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
//  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
//  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
//  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
//  OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ContainerListController.h"
#import "ContainerController.h"
#import "ContainerList.h"
#import "BooksTableViewCell.h"
#import "Book.h"

@implementation ContainerListController

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init {
	if (self = [super initWithTitle:LocStr(@"CONTAINER_LIST_TITLE") navBarHidden:NO]) {
		m_paths = [ContainerList shared].paths;

		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(onContainerListDidChange)
			name:kSDKLauncherContainerListDidChange object:nil];
	}

	return self;
}

- (void)loadView {
	self.view = [[UIView alloc] init];

	UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
	m_table = table;
	table.dataSource = self;
	table.delegate = self;
	[self.view addSubview:table];
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    /*if (scrollView == churchBooksTableView) {
        [_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
    }*/
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    /*if (scrollView == churchBooksTableView) {
        [_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
    }*/
    if (!decelerate)
    {
        [self loadContentForVisibleCells];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
{
    [self loadContentForVisibleCells];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [m_table reloadData];
    [self loadContentForVisibleCells];
}

- (void)loadContentForVisibleCells
{
    if ([m_paths count] == 0) {
        return;
    }
    
    NSArray *visiblePaths = [m_table indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths)
    {
        switch (indexPath.section) {
            case 0:
            {
                BooksTableViewCell *cell = (BooksTableViewCell *)[m_table cellForRowAtIndexPath:indexPath];
                [cell loadImage];
            }
                break;
            default:
                break;
        };
    }
}

- (void)onContainerListDidChange {
	m_paths = [ContainerList shared].paths;
	[m_table reloadData];
}

- (UITableViewCell *)
	tableView:(UITableView *)tableView
	cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"BookCell";
    BooksTableViewCell *cell = (BooksTableViewCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
    {
        //CGRect rect = CGRectMake(0.0, 0.0, 320.0, 100.0);
        //cell = [[[ItemTableViewCell alloc] initWithFrame:rect reuseIdentifier:identifier] autorelease];
        cell = [[BooksTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    
    Book *book = [[Book alloc] init];
    NSString *path = [m_paths objectAtIndex:indexPath.row];
    NSArray *components = path.pathComponents;
    book.title = (components == nil || components.count == 0) ?
    @"" : components.lastObject;
    book.author = @"Some author";
    
    //temporary images
    NSArray *imgs = [NSArray arrayWithObjects:@"51Tg3M9XR0L", @"41ZG-FMn8BL",
                    @"41O76wsT0VL", @"51rmu8wfj1L",
                    @"51AtdDrV9bL", @"51ZvxGrNoYL",
                    @"51myLZoxXnL", nil];
    book.img = [imgs objectAtIndex:(indexPath.row % 8)];
    
    [cell setBook:book therow:indexPath.row];
    return cell;
}


- (void)
	tableView:(UITableView *)tableView
	didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *path = [m_paths objectAtIndex:indexPath.row];
	ContainerController *c = [[ContainerController alloc] initWithPath:path];

	if (c != nil) {
		[self.navigationController pushViewController:c animated:YES];
	}
}

- (NSInteger)
	tableView:(UITableView *)tableView
	numberOfRowsInSection:(NSInteger)section
{
	return m_paths.count;
}


- (void)viewDidLayoutSubviews {
	m_table.frame = self.view.bounds;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 75.0;
}

@end
