There is a well-known tool [include-what-you-use](https://github.com/include-what-you-use/include-what-you-use)
(that later will be referenced as IWYU) which uses Clang AST to detect which headers can be safely removed from source code.

This experiment began from idea that IWYU may be too aggressive for use in WebKit code base, because the latter has a lot of conditional compilation. Different ports have their own `#if PLATFORM(X)` blocks. Flso there are various features which can be turned on and off in compilation time, which have different default presets in different ports and may be additionally tuned by the end user. Blocks of conditionally compiled code can be (and often are) mutually exclusive, so there is no way for IWYU to see translation unit which would include all possible code paths at once.

On the other hand, in WebKit code base most of header files define exactly one C++ class, and name of the header is `ClassName.h` when `ClassName` is actual C++ class name.

So, I've decided to implement simpler approach which wouldn't include full-blown C++ parsing. Instead, I've used simple scanning of test for identifier names (remove-unused-headers.pl naively treats all words as C++ indentifiers, and remove-unused-headers-ctags.pl uses [Universal Ctags](https://ctags.io) database). Header is considered to be "useless" if there is no seen identifier which would require it.

Result of experiment is that such naive approach, while designed to be less aggressive than IWYU, is in fact more agressive than it. While it doesn't exclude conditionally compiled parts of code base, it doesn't detect a lot of implicit uses which don't involve spelling out class name anywhere in the source file.

Better solution to ths problem could be running IWYU on several versions of the same translation unit for different conditions, and removing only headers which are useless in all of them.
