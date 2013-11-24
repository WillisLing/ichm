//
//  ITSSProtocol.m
//  ichm
//
//  Created by Robin Lu on 7/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "ITSSProtocol.h"
#import "CHMDocument.h"
#import <libxml/HTMLparser.h>

typedef struct tag_HeadMetaCharset {
    BOOL isEnterHeadElement;
    NSString* charset;
} HeadMetaCharset;

static void elementDidStart( HeadMetaCharset* ctx, const xmlChar *name, const xmlChar **atts );
static void elementDidEnd( HeadMetaCharset* ctx, const xmlChar *name );

static htmlSAXHandler saxHandler = {
    NULL, /* internalSubset */
    NULL, /* isStandalone */
    NULL, /* hasInternalSubset */
    NULL, /* hasExternalSubset */
    NULL, /* resolveEntity */
    NULL, /* getEntity */
    NULL, /* entityDecl */
    NULL, /* notationDecl */
    NULL, /* attributeDecl */
    NULL, /* elementDecl */
    NULL, /* unparsedEntityDecl */
    NULL, /* setDocumentLocator */
    NULL, /* startDocument */
    NULL, /* endDocument */
    (startElementSAXFunc) elementDidStart, /* startElement */
    (endElementSAXFunc) elementDidEnd, /* endElement */
    NULL, /* reference */
    NULL, /* characters */
    NULL, /* ignorableWhitespace */
    NULL, /* processingInstruction */
    NULL, /* comment */
    NULL, /* xmlParserWarning */
    NULL, /* xmlParserError */
    NULL, /* xmlParserError */
    NULL, /* getParameterEntity */
};


@implementation ITSSProtocol

-(id)initWithRequest:(NSURLRequest *)request
      cachedResponse:(NSCachedURLResponse *)cachedResponse
			  client:(id <NSURLProtocolClient>)client
{
    return [super initWithRequest:request cachedResponse:cachedResponse client:client];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	BOOL canHandle = [[[request URL] scheme] isEqualToString:@"itss"];
    return canHandle;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

-(void)stopLoading
{
}

-(void)startLoading
{
    NSURL *url = [[self request] URL];
	CHMDocument *doc = [[self request] chmDoc];
	NSString *encoding = [[self request] encodingName];
	
	if( !doc ) {
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
		return;
    }
	
    NSData *data;
    NSString *path;
    if( [url parameterString] ) {
		path = [NSString stringWithFormat:@"%@;%@", [url path], [url parameterString]];
    }
    else {
		path = [url path];
    }
	
	if (![doc exist:path])
	{
		path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	}
	data = [doc content:path];
    
    if( !data ) {
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
		return;
    }
    
	NSString *type = nil;
	if ([[[path pathExtension] lowercaseString] isEqualToString:@"html"] ||
         [[[path pathExtension] lowercaseString] isEqualToString:@"htm"])
		type = @"text/html";
    /* ----- */
    NSString* htmlMetaCharsetEncording = [self get_HtmlMetaCharsetEncoding_FromHtmlContentData:data];
    if (htmlMetaCharsetEncording) {
        encoding = htmlMetaCharsetEncording;
    }
    NSURLResponse *response = [[NSURLResponse alloc] initWithURL: [[self request] URL]
														MIMEType:type
										   expectedContentLength:[data length]
												textEncodingName:encoding];
    [[self client] URLProtocol:self     
			didReceiveResponse:response 
			cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
	
    [response release];	
}

- (NSString*)get_HtmlMetaCharsetEncoding_FromHtmlContentData:(NSData*)contentData
{
    HeadMetaCharset hmc;
    hmc.isEnterHeadElement = NO;
    hmc.charset = NULL;
    
    htmlDocPtr doc = htmlSAXParseDoc((xmlChar*)[contentData bytes], "UTF-8", &saxHandler, &hmc);
    
    if (doc) {
        xmlFreeDoc(doc);
    }
    
    return hmc.charset;
}

@end

# pragma mark NSXMLParser delegation
static void elementDidStart( HeadMetaCharset* ctx, const xmlChar *name, const xmlChar **atts )
{
    if (0 == strcasecmp("head", (char *)name))
    {
        ctx->isEnterHeadElement = YES;
    }
    else if (0 == strcasecmp("meta", (char *)name))
    {
        if (ctx->isEnterHeadElement)
        {
            if (atts != NULL) {
                for (int i = 0; atts[i] != NULL; ++i) {
                    NSLog(@"atts: <%@>", [NSString stringWithUTF8String:(char*)(atts[i])]);
                    if (i % 2 == 1) {
                        NSString* att_value = [NSString stringWithUTF8String:(char*)(atts[i])];
                        att_value = [att_value stringByReplacingOccurrencesOfString:@" " withString:@""];
                        
                        NSArray* components = [att_value componentsSeparatedByString:@";"];
                        for (NSString* __comp in components) {
                            NSRange range = [__comp rangeOfString:@"charset=" options:NSCaseInsensitiveSearch];
                            if (range.length != 0) {
                                ctx->charset = [__comp substringFromIndex:NSMaxRange(range)];
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}

static void elementDidEnd( HeadMetaCharset* ctx, const xmlChar *name )
{
}

@implementation NSURLRequest (SpecialProtocol)

- (CHMDocument *)chmDoc
{
	return [NSURLProtocol propertyForKey:@"chmdoc" inRequest:self];
}

- (NSString *)encodingName
{
	return [NSURLProtocol propertyForKey:@"encoding" inRequest:self];
}
@end



@implementation NSMutableURLRequest (SpecialProtocol)

- (void)setChmDoc:(CHMDocument *)doc 
{
	[NSURLProtocol setProperty:doc forKey:@"chmdoc" inRequest:self];
}

- (void)setEncodingName:(NSString *)name
{
	[NSURLProtocol setProperty:name forKey:@"encoding" inRequest:self];
}
@end
