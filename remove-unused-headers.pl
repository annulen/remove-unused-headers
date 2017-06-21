#!/usr/bin/env perl

use Data::Dumper;
use File::Basename;
use File::Slurp;
use strict;
use warnings;

my %specialHeaders = (
    'wtf/Optional.h' => [ 'optional', 'nullopt', 'nullopt_t' ],
    'wtf/FastMalloc.h' => [ 'WTF_MAKE_FAST_ALLOCATED' ],
    'wtf/Noncopyable.h' => [ 'WTF_MAKE_NONCOPYABLE' ],
    'wtf/DataLog.h' => [ 'dataLog\w*' ],
    'Compiler.h' => [ '\w*UNUSED\w*', 'COMPILER\w*', '(UN)?LIKELY', '\w*INLINE\w*' ],
    'wtf/Compiler.h' => [ '\w*UNUSED\w*', 'COMPILER\w*', '(UN)?LIKELY', '\w*INLINE\w*' ],
    'Threading.h' => [ 'Thread', 'ThreadIdentifier', 'currentThread' ],
    'wtf/Threading.h' => [ 'Thread', 'ThreadIdentifier', 'currentThread' ],
    'wtf/Atomics.h' => [ 'Atomic', 'atomic\w*' ],
    'wtf/FastTLS.h' => [ 'FAST_TLS' ],
    'wtf/HashFunctions.h' => [ 'DefaultHash' ],
    'wtf/PageBlock.h' => [ 'PageBlock', 'pageSize', 'isPageAligned', 'isPowerOfTwo' ],
    'wtf/ThreadingPrimitives.h' => [ 'PlatformMutex', 'PlatformCondition', 'Mutex', 'Condition' ],
    'wtf/Hasher.h' => [ 'StringHasher', 'IntegerHasher' ],
    'wtf/GetPtr.h' => [ 'GetPtrHelper\w*', 'getPtr' ],
    'RandomNumber.h' => [ 'randomNumber' ],
    'wtf/text/StringHash.h' => [ 'StringHash', 'ASCIICaseInsensitiveHash' ],
    'wtf/text/SymbolImpl.h' => [ 'SymbolImpl', 'RegisteredSymbolImpl' ],
    'wtf/CryptographicallyRandomNumber.h' => [ 'cryptographicallyRandomNumber' ],
    'wtf/RefCounted.h' => [ 'RefCounted', 'RefCountedBase' ],
    'APICast.h' => [ 'toRef', 'toJS\w*' ],
    'Supplementable.h' => [ 'Supplementable', 'Supplement' ],
    'CSSPropertyNames.h' => [ 'CSSProperty\w*' ],
    'CSSValueKeywords.h' => [ 'CSSValue\w*' ],
    'SelectorCompiler.h' => [ 'SelectorCompiler', 'SelectorCompilationStatus', 'SelectorContext', 'compileSelector' ],
    'RuleFeature.h' => [ 'RuleFeature', 'RuleFeatureSet' ],
    'FontSelectionAlgorithm.h' => [ 'FontSelectionAlgorithm', 'FontSelectionValue' ],
#    'CSSCalculationValue.h' => [ 'CSSCalcValue' ],
    'StyleRelations.h' => [ 'Relation', 'Relations' ],
    'StyleRule.h' => [ 'StyleRule\w*', 'DeferredStyleGroupRuleList' ],
    'JSDOMPromiseDeferred.h' => [ 'DOMPromiseDeferred' ],
    'CachedFont.h' => [ 'CachedFont', 'FontFeatureSettings' ],
    'FontTaggedSettings.h' => [ 'FontTaggedSettings', 'FontFeatureSettings' ],
    'wtf/BloomFilter.h' => [ 'CountingBloomFilter', 'BloomFilter' ],
    'Length.h' => [ 'ValueRange', 'Length', 'LengthType' ],
    'ScrollableArea.h' => [ 'ScrollableArea', 'scrollableArea' ],
    'FocusController.h' => [ 'FocusController', 'focusController' ],
    'Microtasks.h.' => [ 'Microtask', 'MicrotaskQueue' ],
    'JSDOMPromiseDeferred.h' => [ 'DeferredPromise', 'DOMPromiseDeferred', 'DOMPromiseDeferredBase' ],
    'StyleValidity.h' => [ 'Validity', 'InvalidationMode' ],
    'StyleChange.h' => [ 'Change' ],
    'SimulatedClickOptions.h' => [ 'SimulatedClickMouseEventOptions', 'SimulatedClickVisualOptions' ],
    'FragmentScriptingPermission.h' => [ 'ParserContentPolicy' ],
    'DragImage.h' => [ 'DragImage', 'DragImageRef' ],
    'ElementTraversal.h' => [ 'Traversal', 'ElementTraversal' ],
    'Traversal.h' => [ 'NodeIteratorBase' ],
);

my %skippedFiles = (
    'Source/WTF/wtf/Compiler.h' => 1,
    'Source/WTF/wtf/Platform.h' => 1,
    'Source/WTF/wtf/WindowsExtras.h' => 1,
    'Source/WTF/wtf/ParallelJobs.h' => 1,
    'Source/WTF/wtf/dtoa.h' => 1,
    'Source/WTF/wtf/text/WTFString.h' => 1,
    'Source/WTF/wtf/Deque.h' => 1,
    'Source/WebCore/css/StyleBuilderCustom.h' => 1
);

my %ignoredHeaders = (
    'config.h' => 1,

    # WTF
    'wtf/Assertions.h' => 1,
    'wtf/ASCIICType.h' => 1,
    'wtf/CheckedArithmetic.h' => 1,
    'wtf/CurrentTime.h' => 1,
    'wtf/GraphNodeWorklist.h' => 1,
    'ExportMacros.h' => 1,
    'wtf/ExportMacros.h' => 1,
    'wtf/Platform.h' => 1,
    'wtf/FastMalloc.h' => 1,
    'wtf/Forward.h' => 1,
    'wtf/text/WTFString.h' => 1,
    'wtf/text/StringConcatenate.h' => 1,
    'wtf/ListDump.h' => 1,
    'wtf/NotFound.h' => 1,
    'wtf/TypeCasts.h' => 1,
    'wtf/text/IntegerToStringConversion.h' => 1,
    'wtf/text/icu/UTextProviderLatin1.h' => 1,
    'wtf/text/StringOperators.h' => 1,
    'wtf/dtoa.h' => 1,
    'wtf/SixCharacterHash.h' => 1,
    'wtf/MainThread.h' => 1,
    'wtf/VMTags.h' => 1,

    # JSC
    'Error.h' => 1,
    'JSExportMacros.h' => 1,
    'JavaScriptCore/JSBase.h' => 1,
    'JavaScriptCore/WebKitAvailability.h' => 1,
    'InspectorProtocolObjects.h' => 1,

    # WebCore
    'ExceptionOr.h' => 1,
    'GraphicsTypes.h' => 1,
    'RenderStyleConstants.h' => 1,
    'UnicodeBidi.h' => 1,
    'CSSPrimitiveValueMappings.h' => 1,
    'TextFlags.h' => 1,
    'ImageOrientation.h' => 1,
    'CSSCalculationValue.h' => 1,
    'Frame.h' => 1,
    'Settings.h' => 1,
    'CSSParserMode.h' => 1,
    'CSSParserToken.h' => 1,
    'PlatformExportMacros.h' => 1,
    'EventTrackingRegions.h' => 1,
    'EventTargetInterfaces.h' => 1,
    'EventTarget.h' => 1,
    'EventInterfaces.h' => 1,

    'arpa/inet.h' => 1,

    'glib.h' => 1,
    'gcrypt.h' => 1,

    'math.h' => 1,
    'inttypes.h' => 1,
    'unistd.h' => 1,
    'semaphore.h' => 1,
    'signal.h' => 1,
    'windows.h' => 1,
    'wchar.h' => 1,
    'errno.h' => 1,
    'malloc.h' => 1,
    'pthread.h' => 1,
    'string.h' => 1,
    'strings.h' => 1,
    'limits.h' => 1,
    'time.h' => 1,
    'ctype.h' => 1,
    'ieeefp.h' => 1
);

sub headerIsIgnored {
    my $header = shift;

    return 1 if (exists $ignoredHeaders{$header});
    return 1 if $header =~ m{^unicode/} || $header =~ m{^sys/} || $header =~ m{^mach/} || $header =~ m{^System/} || $header =~ m{^Security/} || $header =~ m{^dispatch/} || $header =~ m{^CommonCrypto/} || $header =~ m{^machine/} || $header =~ m{^objc/} || $header =~ m{^gio/} || $header =~ m{^wtf/spi/} || $header =~ m{CoreFoundation/} || $header =~ m{^xpc/} || $header =~ m{^mach-o/} || $header =~ m{^os/} || $header =~ m{^WebKitAdditions/};
    return 1 if $header =~ /Extras\.h$/ || $header =~ /Inlines\.h$/ || $header =~ /Common\.h$/ || $header =~ /intrin\.h$/ || $header =~ /Traits\.h$/ || $header =~ /Iterators\.h$/ || $header =~ /Functions\.h$/ || $header =~ /Hash\.h/ || $header =~ /Types\.h$/ || $header =~ /Defs\.h$/ || $header =~ /Names\.h$/;
    return $header =~ /^std/ || $header !~ /\.h$/
}

sub identifiersForHeader {
    my $header = shift;

    if (exists $specialHeaders{$header}) {
        return @{$specialHeaders{$header}};
    }

    #my $headerWithoutPath = (split '/', $header)[-1];
    my $basename = basename($header, '.h');
    my @result = ($basename);
    if ($basename =~ /^B3(.*)/) {
        push @result, $1;
    }
    if ($basename =~ /^JSC(.*)/) {
        push @result, $1;
    }
    return @result;
}

sub parseFile {
    my ($lines, $headers) = @_;
    my %identifiers;

    LINE: for my $line (@$lines) {
        if ($line =~ /^#include [<"](\S+)[>"]/) {
            my $header = $1;
            next LINE if headerIsIgnored($header);

            my @ids = identifiersForHeader($header);
            $headers->{$header} = \@ids;
            for my $i (@ids) {
                $identifiers{$i} = $header;
            }
            next LINE;
        }

        my @ids = keys %identifiers;
        for my $i (@ids) {
            if (exists $identifiers{$i} && $line =~ /\b$i\b/) {
                my $header = $identifiers{$i};
                my @identifiersFromHeader = @{$headers->{$header}};
                for (@identifiersFromHeader) {
                    delete $identifiers{$_};
                }
                delete $headers->{$header};
            }
        }
    }
}

sub writeFile {
    my ($fh, $lines, $headers) = @_;

    LINE: for my $line (@$lines) {
        if ($line =~ /^#include [<"](\S+)[>"]/) {
            next LINE if (exists $headers->{$1});
        }
        print $fh $line;
    }
}

sub processFile {
    my $filename = shift;

    if (open my $fh, '<', $filename) {
        my %headersToRemove;
        my @lines = <$fh>;
        close $fh;

        #print "File: $filename\n";
        parseFile(\@lines, \%headersToRemove);

        if (keys %headersToRemove) {
            if (open my $fh_w, '>', $filename) {
                print "Fixing headers in $filename\n";
                writeFile($fh_w, \@lines, \%headersToRemove);
                close $fh_w;
            } else {
                warn "Could not open $filename for writing: $!";
            }
        }
    } else {
        warn "Could not open $filename: $!";
    }
}

for my $filename (@ARGV) {
    next if exists $skippedFiles{$filename} || $filename =~ m{dtoa/} || $filename =~ m{ForwardingHeaders/} || $filename =~ m{applepay/} || $filename =~ /config\.h$/;
    processFile($filename);
}
