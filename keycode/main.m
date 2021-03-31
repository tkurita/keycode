#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */
#include <getopt.h>

void usage() {
    printf("Usage: keycode [-hv] [-n] [char]\n");
    printf("\n");
    printf("When char is given, print keycode according to the character.\n");
    printf("When char is not given, print mapping keycodes to characters.\n");
    printf("\n");
    printf("-n : Do not print the trailing newline character.\n");
    printf("-h : Print this help messages.\n");
    printf("-v : Print version information.\n");
}

void showVersion() {
    printf("keycode 1.0 copyright 2021, Kurita Tetsuro\n");
}

const UCKeyboardLayout* keyboard_layout()
{
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardLayoutInputSource();
    CFDataRef uchr =
    (CFDataRef)TISGetInputSourceProperty(currentKeyboard,
                                         kTISPropertyUnicodeKeyLayoutData);
    //NSLog(@"%@", CFCopyDescription(uchr));
    return (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);
}

NSString* keyCodeToString(CGKeyCode keyCode, const UCKeyboardLayout* kblayout)
{
    UInt32 deadKeyState = 0;
    UniCharCount maxStringLength = 255;
    UniCharCount actualStringLength = 0;
    UniChar unicodeString[maxStringLength];
    
    OSStatus status = UCKeyTranslate(kblayout,
                                     keyCode, kUCKeyActionDown, 0,
                                     LMGetKbdType(), 0,
                                     &deadKeyState,
                                     maxStringLength,
                                     &actualStringLength, unicodeString);
    
    if (actualStringLength == 0 && deadKeyState)
    {
        status = UCKeyTranslate(kblayout,
                                kVK_Space, kUCKeyActionDown, 0,
                                LMGetKbdType(), 0,
                                &deadKeyState,
                                maxStringLength,
                                &actualStringLength, unicodeString);
    }
    if(actualStringLength > 0 && status == noErr)
        return [[NSString stringWithCharacters:unicodeString
                                        length:(NSUInteger)actualStringLength] lowercaseString];
    return nil;
}

void print_mapping(const UCKeyboardLayout* kblayout)
{
    @autoreleasepool {
        printf("Keycode  | Char\n");
        printf("Dec  Hex |     \n");
        printf("---------------\n");
        size_t i;
        for (i = 0; i < 128; ++i) {
            NSString* str = keyCodeToString((CGKeyCode)i, kblayout);
            if(str == nil) str = @"";
            printf("%3d  %3x |    %s\n", (int)i, (int)i, [str UTF8String]);
        }
    }
}

NSNumber* charToKeyCode(const char c, const UCKeyboardLayout* kblayout)
{
    static NSMutableDictionary* dict = nil;
    
    if (dict == nil)
    {
        dict = [NSMutableDictionary dictionary];
        
        // For every keyCode
        size_t i;
        for (i = 0; i < 128; ++i)
        {
            NSString* str = keyCodeToString((CGKeyCode)i, kblayout);
            if(str != nil && ![str isEqualToString:@""])
            {
                [dict setObject:[NSNumber numberWithInt:(int)i] forKey:str];
            }
        }
    }
    
    NSString * keyChar = [NSString stringWithFormat:@"%c" , c];
    
    return [dict objectForKey:keyChar];
}

int print_keycode(char* str, const UCKeyboardLayout* kblayout)
{
    @autoreleasepool {
        short n = 0;
        while(1) {
            short noerr = 1;
            NSNumber *kc = charToKeyCode(str[n], kblayout);
            if (kc) {
                printf("%d", [kc intValue]);
            } else {
                fprintf(stderr, "No keycode for %c\n", str[n]);
                noerr = 0;
            }
            if (str[++n] == '\0') {
                break;
            } else {
                if (noerr) printf("\n");
            }
        }
    }
    return EXIT_SUCCESS;
}

int main(int argc, char * const  argv[]) {
    static struct option long_options[] = {
        {"version", no_argument, NULL, 'v'},
        {"help", no_argument, NULL, 'h'},
        {"nonewline", no_argument, NULL, 'n'},
        {0, 0}
    };
    
    short nonewline = 0;
    int option_index = 0;
    while(1){
        int c = getopt_long(argc, argv, "vhn",long_options, &option_index);
        if (c == -1)
            break;
        
        switch(c){
            case 'h':
                usage();
                exit(EXIT_SUCCESS);
            case 'v':
                showVersion();
                exit(EXIT_SUCCESS);
            case 'n':
                nonewline = 1;
                break;
            case '?':
            default    :
                fprintf(stderr, "There is unknown option.\n");
                usage();
                exit(EXIT_FAILURE);
                break;
        }
        optarg = NULL;
    }
    
    const UCKeyboardLayout*  kblayout = keyboard_layout();
    if (! kblayout) {
        fprintf(stderr, "Failed to obtain keyboard layout.\n");
        return EXIT_FAILURE;
    }
    
    OSStatus status = EXIT_SUCCESS;
    if (optind == argc) { // No arguments
        print_mapping(kblayout);
    } else {
        short i = optind;
        @autoreleasepool {
            while(1) {
                char *str = argv[i];
                print_keycode(str, kblayout);
                if (++i < argc) {
                    printf("\n");
                } else if (!nonewline) {
                    printf("\n");
                    break;
                } else {
                    break;
                }
            }
        }
    }
    
    return status;
}
