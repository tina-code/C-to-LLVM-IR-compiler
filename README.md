# C-to-LLVM-IR-compiler

(1)編譯程式方式：我將編譯myCompiler.g與myCompiler_test.java兩個檔案的指令都放在Makefile裡面，在command line直接打make即可執行編譯\n
(2)產生ll檔方式：有3個test program(test0.c，test1.c，test2.c)，步驟一結束後，在terminal打make test可以執行把3個檔案丟給myCompiler_test的動作
(3)執行程式：在terminal打make exec，會以lli執行ll檔並產生結果
