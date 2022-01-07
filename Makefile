all:
	java -cp antlr-3.5.2-complete.jar org.antlr.Tool myCompiler.g
	javac -cp ./antlr-3.5.2-complete.jar:. *.java
test:
	java -cp ./antlr-3.5.2-complete.jar:. myCompiler_test test0.c  | tee test0.ll
	java -cp ./antlr-3.5.2-complete.jar:. myCompiler_test test1.c  | tee test1.ll
	java -cp ./antlr-3.5.2-complete.jar:. myCompiler_test test2.c  | tee test2.ll
exec:
	lli test0.ll
	lli test1.ll
	lli test2.ll
clean:
	rm *class
	rm myCompilerParser.java
	rm myCompilerLexer.java
	rm myCompiler.tokens
	rm *.ll