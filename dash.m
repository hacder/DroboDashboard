/*
 ** Very basic drobo tool
 ** communicates with DDServiced via Objective-C Distributed objects.
 ** 
 ** Methods for the DDServer Class found using strings on the DDServiced binary
 ** 
 gcc  -framework Foundation dash.m
 */

#import <Foundation/NSConnection.h>
#import <Foundation/NSPortNameServer.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>
#import <objc/runtime.h>

#import "DDServer.h"
#import "ESATMUpdate.h"
#import "HumanReadableDataSizeHelper.h"

NSAutoreleasePool  *pool;
NSDistantObject *proxy;
DDServer *dd;	


//-(void)listDrobo:(NSDistantObject *)proxy:(DDServer *)dd
void listDrobo(NSDistantObject *proxy, DDServer *dd)
{

	int droboCount = [dd getESACount:proxy];
	
	printf ("Number of drobos connected: %d\n", droboCount );
	int index;
	NSString *esaid;
	for (index=0; index < droboCount; index++) 
	{
		if ([dd getESAId:proxy ESAAtIndex:index ESAID:&esaid]>0) {
			
			//	NSLog(@"getESAId: %d",rVal);
			printf("%d: ID: %s\n",index,[esaid UTF8String]);
		}
	}
	
	
}


int main(int argc, char *argv[])
{
	
	NSSocketPort *port;
	NSConnection *connection;
	const int ddservicedPort = 50005;
	BOOL siunits = false;
	
	pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
	
	[[NSProcessInfo processInfo] arguments];
	
	if([args boolForKey:@"help"])
	{
		printf("Drobo dashboard Utility\nUtility to manage connected Drobos\n");
		printf("Usage: dash <command> [options]\nCOMMANDS:");
		printf ("\tdf df style capacity output\n");
		printf("\tversion information\n");
		printf("\tlist list connected drobos\n");
		printf("\tdisks list disks and status\n");

		printf("\t-esaid <ESAID> Specify which Drobo to use\n");
		printf("\t-h Human readable number format\n");
		printf("\t-si Use 1000 rather than 1024 for human readable display.\n");


		exit(0);
	}

	if([args boolForKey:@"si"]) {
		siunits = true;	
	}
	
	
	port = [[NSSocketPort alloc] initRemoteWithTCPPort:ddservicedPort host:@"localhost"];
	
	if (port == nil) {
		// this is actually a programming error
		NSLog(@"could not setup port");
		exit(-1);
	}
	
	connection = [NSConnection connectionWithReceivePort:nil sendPort:port];
	proxy = [[connection rootProxy] retain];
	
	dd = (DDServer *)proxy;
	
	// NSLog(@"%@",[proxy description]);
	
	NSArray *arg =  [[NSProcessInfo processInfo] arguments];
	
	if ([dd subscribeClient:proxy] == 1) {
		
		if([args boolForKey:@"list"]) {
			//[self listDrobo:proxy:dd];
			listDrobo(proxy,dd);
			exit(0);
		}
		
		if ([dd getESACount:proxy] > 0) {
			
			
			
			
			NSString *esaid = [args stringForKey:@"esaid"];
			
			if (esaid == nil) { 
				esaid = [[NSString alloc] init];
				// get the first drobo
				[dd getESAId:proxy ESAAtIndex:0 ESAID:&esaid];
			}
			
			NSString *esaupdate = [[NSString alloc] init];
			NSString *command = [[NSData alloc] init];

			if (esaid!=nil) {
				
				//	NSLog(@"getESAId: %d",rVal);
				//		NSLog(@"Drobo ID: %@",esaid);
				
				
				[dd TMInit:proxy 
			simulationMode:0 
		   PollingInterval:5 
			  VerboseLevel:0 
				  FileMode:0 
	 StartNetMonitorThread:0];
				
				[dd registerESAEventListener:proxy];
				
				int riVal;
				
				do {
					// should probably sleep
					riVal = [dd getNextESAEventType:proxy];
				} while (riVal != 1);
				
				NSString *update;			
				
				if ([dd getNextESAUpdateEvent:proxy ESAID:&esaid ESAUpdate:&update]>0) 
				{
					
					ESATMUpdate *esa;
					
					esa = [[ESATMUpdate alloc] initWithString:update];
					
					if ([args boolForKey:@"version"]) {
						printf("ID:           %s\n",[[esa getESAID] UTF8String]);
						printf("Serial:       %s\n",[[esa getSerial] UTF8String]);
						printf("Name:         %s\n",[[esa getName] UTF8String]);
						printf("Version:      %s\n",[[esa getVersion] UTF8String]);
						printf("Release Date: %s\n",[[esa getReleaseDate] UTF8String]);
						
						printf("Architecture: %s\n",[[esa getArch] UTF8String]);
						printf("Features:     %d\n",[esa getFirmwareFeatures]);
						
						exit(0);
					}
					
					if([args boolForKey:@"df"]) {
						
						printf("%20s\t%s\t%s\t%s\t%s\n","Name","Total","Used","Free","Percent");	
						if([args boolForKey:@"h"]) {
							printf ("%20s\t%s\t%s\t%s\t%lld%%\n",[[esa getName] UTF8String],
									[[HumanReadableDataSizeHelper humanReadableSizeFromBytes:[NSNumber numberWithLongLong:[esa getTotalCapacityProtected]] useSiPrefixes:siunits  useSiMultiplier:siunits] UTF8String],
									[[HumanReadableDataSizeHelper humanReadableSizeFromBytes:[NSNumber numberWithLongLong:[esa getUsedCapacityProtected]] useSiPrefixes:siunits  useSiMultiplier:siunits] UTF8String],
									[[HumanReadableDataSizeHelper humanReadableSizeFromBytes:[NSNumber numberWithLongLong:[esa getFreeCapacityProtected]] useSiPrefixes:siunits  useSiMultiplier:siunits ] UTF8String],
									
									100*[esa getUsedCapacityProtected]/[esa getTotalCapacityProtected]);
						} else {
							printf ("%20s\t%lld\t%lld\t%lld\t%lld%%\n",[[esa getName] UTF8String],
									[esa getTotalCapacityProtected],
									[esa getUsedCapacityProtected],
									[esa getFreeCapacityProtected],
									
									100*[esa getUsedCapacityProtected]/[esa getTotalCapacityProtected]);
						}
						exit(0);
					}
					
					if ([args boolForKey:@"disks"])
					{
						
						int disks = [esa getSlotCountExp];
						printf("Number of Disks: %d\n",disks);
						int slot;
						for (slot=0; slot < disks; slot++)
						{
							if([args boolForKey:@"h"]) {
								printf("Disk: %d size: %s status: %d\n",slot,
									   [
										[HumanReadableDataSizeHelper humanReadableSizeFromBytes:
										 [NSNumber numberWithLongLong:
										  [esa getPhysicalCapacityAtSlot:slot]
										  ]
										useSiPrefixes:siunits  useSiMultiplier:siunits
										 ] 
										UTF8String],
									   [esa getStatusAtSlot:slot]);
							} else {
								printf("Disk: %d size: %lld status: %d\n",slot,[esa getPhysicalCapacityAtSlot:slot], [esa getStatusAtSlot:slot]);
							}
						}
						
						
					}
					
					if([args boolForKey:@"xpath"]) {
						NSError *errorString;
						
						NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithXMLString:update
																				 options:0
																				   error:&errorString];
						NSXMLNode *aNode = [xmlDoc rootElement];
						while (aNode = [aNode nextNode]) {
							NSLog(@"Name: %@=%@",[aNode XPath],[aNode objectValue]);
						}
					}
					
					
				} else {
					NSLog(@"Error Parsing response");
				}
				
				[dd unregisterESAEventListener:proxy];
				[dd TMExit:proxy];
				
				//	NSLog(@"getNextESAUpdateEvent: %d",riVal);
				//	NSLog (@"getNextESAUpdateEvent:%@",update);
			}
		} else {
			NSLog(@"No Drobos Detected.");
		}
		[dd unsubscribeClient:proxy];
	}
	//		[proxy unsubscribeClient:@"drobodash"];
	
	
	[pool release];
	return 0;
}
