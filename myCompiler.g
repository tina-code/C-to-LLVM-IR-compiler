grammar myCompiler;

options {
   language = Java;
}

@header {
    // import packages here.
    import java.util.HashMap;
    import java.util.ArrayList;
}

@members {
    boolean TRACEON = false;

    // Type information.
    public enum Type{
       ERR, BOOL, INT, FLOAT, CHAR, CONST_INT,CONST_FLOAT;
    }

    // This structure is used to record the information of a variable or a constant.
    class tVar {
	   int   varIndex; // temporary variable's index. Ex: t1, t2, ..., etc.
	   int   iValue;   // value of constant integer. Ex: 123.
	   float fValue;   // value of constant floating point. Ex: 2.314.
	};

    class Info {
       Type theType;  // type information.
       tVar theVar;
	   
	   Info() {
          theType = Type.ERR;
		  theVar = new tVar();
	   }
    };

	
    // ============================================
    // Create a symbol table.
	// ArrayList is easy to extend to add more info. into symbol table.
	//
	// The structure of symbol table:
	// <variable ID, [Type, [varIndex or iValue, or fValue]]>
	//    - type: the variable type   (please check "enum Type")
	//    - varIndex: the variable's index, ex: t1, t2, ...
	//    - iValue: value of integer constant.
	//    - fValue: value of floating-point constant.
    // ============================================

    HashMap<String, Info> symtab = new HashMap<String, Info>();

    // labelCount is used to represent temporary label.
    // The first index is 0.
    int labelCount = 0;
	
    // varCount is used to represent temporary variables.
    // The first index is 0.
    int varCount = 0;

    int condCount = 0; 
    int temp = 0;
    int x = 0;
    int y = 0;
    
    // Record all assembly instructions.
    List<String> TextCode = new ArrayList<String>();


    /*
     * Output prologue.
     */
    void prologue()
    {
       TextCode.add("; === prologue ====");
       TextCode.add("declare dso_local i32 @printf(i8*, ...)\n");
       TextCode.add("@.strf = private unnamed_addr constant [4 x i8] c\"\%f\\0A\\00\", align 1");
       TextCode.add("@.strd = private unnamed_addr constant [4 x i8] c\"\%d\\0A\\00\", align 1\n");
       TextCode.add("define dso_local i32 @main()");
	    TextCode.add("{");
    }
    
	
    /*
     * Output epilogue.
     */
    void epilogue()
    {
       /* handle epilogue */
       TextCode.add("\n; === epilogue ===");
	    TextCode.add("ret i32 0");
       TextCode.add("}");
    }
    
    
    /* Generate a new label */
    String newLabel()
    {
       labelCount ++;
       return (new String("L")) + Integer.toString(labelCount);
    } 
    
    
    public List<String> getTextCode()
    {
       return TextCode;
    }
}

program: VOID MAIN '(' ')'
        {
           /* Output function prologue */
           prologue();
        }

        '{' 
           declarations
           statements
        '}'
        {
	     if (TRACEON)
	       System.out.println("VOID MAIN () {declarations statements}");

           /* output function epilogue */	  
           epilogue();
        }
        ;


declarations: type Identifier ';' declarations
        {
           if (TRACEON)
              System.out.println("declarations: type Identifier : declarations");

           if (symtab.containsKey($Identifier.text)) {
              // variable re-declared.
              System.out.println("Type Error: " + 
                                  $Identifier.getLine() + 
                                 ": Redeclared identifier.");
              System.exit(0);
           }
                 
           /* Add ID and its info into the symbol table. */
	      Info the_entry = new Info();
		   the_entry.theType = $type.attr_type;
		   the_entry.theVar.varIndex = varCount;
		   varCount ++;
		   symtab.put($Identifier.text, the_entry);

           // issue the instruction.
		   // Ex: \%a = alloca i32, align 4
           if ($type.attr_type == Type.INT) { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i32, align 4");
           }
           if ($type.attr_type == Type.FLOAT) { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca float, align 4");
           }
        }
        | 
        {
           if (TRACEON)
              System.out.println("declarations: ");
        }
        ;


type
returns [Type attr_type]
    : INT { if (TRACEON) System.out.println("type: INT"); $attr_type=Type.INT; }
    | CHAR { if (TRACEON) System.out.println("type: CHAR"); $attr_type=Type.CHAR; }
    | FLOAT {if (TRACEON) System.out.println("type: FLOAT"); $attr_type=Type.FLOAT; }
	;


statements:statement statements
          |
          ;


statement: assign_stmt ';'
         | if_stmt
         | func_no_return_stmt ';'
         | for_stmt
         | PRINTF '(' LITERAL ',' Identifier ')' ';'
         {  //Type the_type = symtab.get($Identifier.text).theType;
            int vIndex = symtab.get($Identifier.text).theVar.varIndex;
            if (symtab.get($Identifier.text).theType == Type.INT) { 
              TextCode.add("\%t" + varCount + " = load i32, i32* \%t" + vIndex);
				  varCount ++; 
              temp=varCount-1;
              TextCode.add("\%t" + varCount + " = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 " + "\%t" + temp + ")");
              varCount++;
            }
            if (symtab.get($Identifier.text).theType == Type.FLOAT) { 
              TextCode.add("\%t" + varCount + " = load float, float* \%t" + vIndex);
				  varCount ++;
              temp=varCount-1; 
              TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double"); 
              varCount ++;
              temp=varCount-1; 
              TextCode.add("\%t" + varCount + " = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strf, i64 0, i64 0), double " + "\%t" + temp + ")");
              varCount++;
            }
         }
         ;

for_stmt: FOR '(' assign_stmt ';'
                  cond_expression ';'
                  assign_stmt
              ')'
                  block_stmt
        ;
		 
		 
if_stmt
            : if_then_stmt if_else_stmt
            { 
               TextCode.add("lend" + ":" + "\t\t\t\t;");
               TextCode.add("ret i32 0");
            }
            ;

	   
if_then_stmt
            : IF '(' cond_expression ')' 
            {
               temp=labelCount-1;
               TextCode.add("l" + temp + ":" + "\t\t\t\t;");
            }
            block_stmt
            {
               TextCode.add("br label \%lend");
            }
            ;


if_else_stmt
            : ELSE
            {
               TextCode.add("l" + labelCount + ":" + "\t\t\t\t;");
            }
             block_stmt
            {
               TextCode.add("br label \%lend");
            }
            |
            ;

				  
block_stmt: '{' statements '}'
	  ;


assign_stmt: Identifier '=' arith_expression
             {
                Info theRHS = $arith_expression.theInfo;
				    Info theLHS = symtab.get($Identifier.text); 
		   
                if ((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {		   
                   // issue store insruction.
                   // Ex: store i32 \%tx, i32* \%ty
                   TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex);
				    } 
                else if ((theLHS.theType == Type.INT) &&(theRHS.theType == Type.CONST_INT)) {
                   // issue store insruction.
                   // Ex: store i32 value, i32* \%ty
                   TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex);				
				    }
                else if ((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                   TextCode.add("store float \%t" + theRHS.theVar.varIndex + ", float* \%t" + theLHS.theVar.varIndex);				
				    }
                else if ((theLHS.theType == Type.FLOAT) &&(theRHS.theType == Type.CONST_FLOAT)) {
                   long ans = Double.doubleToLongBits(theRHS.theVar.fValue);
                   TextCode.add("store float " + "0x" + Long.toHexString(ans) + ", float* \%t" + theLHS.theVar.varIndex);				
				    }
			    }
             ;

		   
func_no_return_stmt: Identifier '(' argument ')'
                   ;


argument: arg (',' arg)*
        ;

arg: arith_expression
   | STRING_LITERAL
   ;
		   
cond_expression: a=arith_expression 
                 (  '==' b=arith_expression
                    {  
                      Info theRHS = $b.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp eq i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp eq i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp oeq float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                  | '!=' c=arith_expression
                    {  
                      Info theRHS = $c.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp ne i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp ne i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp one float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                  | '>' d=arith_expression
                    {  
                      Info theRHS = $d.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sgt i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp sgt i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp ogt float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                  | '>=' e=arith_expression
                    {  
                      Info theRHS = $e.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sge i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp sge i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp oge float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                  | '<' f=arith_expression
                    {  
                      Info theRHS = $f.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp slt i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp slt i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp olt float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                  | '<=' g=arith_expression
                    {  
                      Info theRHS = $g.theInfo;
				          Info theLHS = $a.theInfo; 
                      if((theLHS.theType == Type.INT) && (theRHS.theType == Type.INT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.INT) && (theRHS.theType == Type.CONST_INT)) {
                        x=varCount-1;
                        TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + x + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.INT)) {
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = icmp sle i32 " + theLHS.theVar.iValue + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.CONST_INT) && (theRHS.theType == Type.CONST_INT)) { 
                        TextCode.add("\%t" + varCount + " = icmp sle i32 " + theLHS.theVar.iValue + ", " + theRHS.theVar.iValue);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                      else if((theLHS.theType == Type.FLOAT) && (theRHS.theType == Type.FLOAT)) {
                        x=varCount-2;
                        y=varCount-1;  
                        TextCode.add("\%t" + varCount + " = fcmp ole float \%t" + x + ", \%t" + y);
                        temp=labelCount;
                        labelCount++;
                        TextCode.add("br i1 \%t" + varCount + ", label \%l" + temp + ", label \%l" + labelCount);
                        varCount++;
                      }
                    } 
                 )*
               ;
			   
arith_expression
returns [Info theInfo]
@init {theInfo = new Info();}
                : a=multExpr { $theInfo=$a.theInfo; }
                 ( '+' b=multExpr
                    {
                       // We need to do type checking first.
                       // ...
					  
                       // code generation.					   
                       if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                           TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       } 
                       else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                           TextCode.add("\%t" + varCount + " = add nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                           TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.CONST_INT;					            
                           $theInfo.theVar.iValue = $a.theInfo.theVar.iValue + $b.theInfo.theVar.iValue;					           
                       }
                       else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                           TextCode.add("\%t" + varCount + " = fadd float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       } 
                       else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                           varCount++;
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fadd double " + $a.theInfo.theVar.fValue + ", " + "\%t" + temp );
                           varCount++;
                           temp=varCount-1;
					            TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                           varCount++;
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fadd double \%t" + temp + ", " + $b.theInfo.theVar.fValue);
                           varCount++;
                           temp=varCount-1;
					            TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.CONST_FLOAT;					            
                           $theInfo.theVar.fValue = $a.theInfo.theVar.fValue + $b.theInfo.theVar.fValue;					           
                       }
                    }
                 | '-' c=multExpr
                   {
                       if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                           TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       } 
                       else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                           TextCode.add("\%t" + varCount + " = sub nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                           TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.INT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.CONST_INT;					           
                           $theInfo.theVar.iValue = $a.theInfo.theVar.iValue - $c.theInfo.theVar.iValue;					            
                       }
                       else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                           TextCode.add("\%t" + varCount + " = fsub float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
					   
					            // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       } 
                       else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                           varCount++;
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fsub double " + $a.theInfo.theVar.fValue + ", " + "\%t" + temp );
                           varCount++;
                           temp=varCount-1;
					            TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                           varCount++;
                           temp=varCount-1;
                           TextCode.add("\%t" + varCount + " = fsub double \%t" + temp + ", " + $c.theInfo.theVar.fValue);
                           varCount++;
                           temp=varCount-1;
					            TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.FLOAT;
					            $theInfo.theVar.varIndex = varCount;
					            varCount ++;
                       }
                       else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                           // Update arith_expression's theInfo.
					            $theInfo.theType = Type.CONST_FLOAT;					            
                           $theInfo.theVar.fValue = $a.theInfo.theVar.fValue - $c.theInfo.theVar.fValue;					           
                       }
                   }
                 )*
                 ;

multExpr
returns [Info theInfo]
@init {theInfo = new Info();}
          : a=signExpr { $theInfo=$a.theInfo; }
          ( '*' b=signExpr
            {
                if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                   TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               } 
               else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                   TextCode.add("\%t" + varCount + " = mul nsw i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
					   
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                   TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
					   
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.CONST_INT;
                   $theInfo.theVar.iValue = $a.theInfo.theVar.iValue * $b.theInfo.theVar.iValue;
               }
               else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                   TextCode.add("\%t" + varCount + " = fmul float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               } 
               else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.FLOAT)) {
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                   varCount++;
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fmul double " + $a.theInfo.theVar.fValue + ", " + "\%t" + temp );
                   varCount++;
                   temp=varCount-1;
					    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                   varCount++;
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fmul double \%t" + temp + ", " + $b.theInfo.theVar.fValue);
                   varCount++;
                   temp=varCount-1;
					    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.CONST_FLOAT;
                   $theInfo.theVar.fValue = $a.theInfo.theVar.fValue * $b.theInfo.theVar.fValue;
               }
            }               
          | '/' c=signExpr
             {
               if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                   TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
					   
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               } 
               else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                   TextCode.add("\%t" + varCount + " = sdiv i32 " + $a.theInfo.theVar.iValue + ", " + "\%t" + $b.theInfo.theVar.varIndex);
					 
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                   TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
					
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.INT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.CONST_INT;
                   $theInfo.theVar.iValue = $a.theInfo.theVar.iValue / $c.theInfo.theVar.iValue;
               }
               else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                   TextCode.add("\%t" + varCount + " = fdiv float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
					
					    // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               } 
               else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($c.theInfo.theType == Type.FLOAT)) {
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                   varCount++;
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fdiv double " + $a.theInfo.theVar.fValue + ", " + "\%t" + temp );
                   varCount++;
                   temp=varCount-1;
					    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.FLOAT) && ($c.theInfo.theType == Type.CONST_FLOAT)) {
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fpext float \%t" + temp + " to double");
                   varCount++;
                   temp=varCount-1;
                   TextCode.add("\%t" + varCount + " = fdiv double \%t" + temp + ", " + $c.theInfo.theVar.fValue);
                   varCount++;
                   temp=varCount-1;
					    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + temp + " to float");
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.FLOAT;
					    $theInfo.theVar.varIndex = varCount;
					    varCount ++;
               }
               else if (($a.theInfo.theType == Type.CONST_FLOAT) && ($b.theInfo.theType == Type.CONST_FLOAT)) {
                   // Update arith_expression's theInfo.
					    $theInfo.theType = Type.CONST_FLOAT;
                   $theInfo.theVar.fValue = $a.theInfo.theVar.fValue / $b.theInfo.theVar.fValue;
               }
             }
	  )*
	  ;

signExpr
returns [Info theInfo]
@init {theInfo = new Info();}
        : a=primaryExpr { $theInfo=$a.theInfo; } 
        | '-' b=primaryExpr
	;
		  
primaryExpr
returns [Info theInfo]
@init {theInfo = new Info();}
           : Integer_constant
	        {
            $theInfo.theType = Type.CONST_INT;
			   $theInfo.theVar.iValue = Integer.parseInt($Integer_constant.text);
           }
           | Floating_point_constant
           {
            $theInfo.theType = Type.CONST_FLOAT;
            $theInfo.theVar.fValue = Float.parseFloat($Floating_point_constant.text);
           }
           | Identifier
           {
            // get type information from symtab.
            Type the_type = symtab.get($Identifier.text).theType;
				$theInfo.theType = the_type;

            // get variable index from symtab.
            int vIndex = symtab.get($Identifier.text).theVar.varIndex;
				
            switch (the_type) {
              case INT: 
                  // get a new temporary variable and
				      // load the variable into the temporary variable.
                         
				      // Ex: \%tx = load i32, i32* \%ty.
				      TextCode.add("\%t" + varCount + " = load i32, i32* \%t" + vIndex);
				          
					   // Now, Identifier's value is at the temporary variable \%t[varCount].
					   // Therefore, update it.
					   $theInfo.theVar.varIndex = varCount;
					   varCount ++;
                  break;
              case FLOAT:
                  // get a new temporary variable and
						 // load the variable into the temporary variable.
                         
						 // Ex: \%tx = load float, float* \%ty.
						 TextCode.add("\%t" + varCount + " = load float, float* \%t" + vIndex);
				         
						 // Now, Identifier's value is at the temporary variable \%t[varCount].
						 // Therefore, update it.
						 $theInfo.theVar.varIndex = varCount;
						 varCount ++;
                   break;
              case CHAR:
                   break;
			
                }
            }
	   | '&' Identifier
	   | '(' a=arith_expression ')'
        { 
           if($a.theInfo.theType == Type.INT) {
              $theInfo.theType = Type.INT;
           }
           else if($a.theInfo.theType == Type.FLOAT){
              $theInfo.theType = Type.FLOAT;
           }
           else if($a.theInfo.theType == Type.CONST_INT){
              $theInfo.theType = Type.CONST_INT;
              $theInfo.theVar.iValue = $a.theInfo.theVar.iValue;
           }
           else if($a.theInfo.theType == Type.CONST_FLOAT){
              $theInfo.theType = Type.CONST_FLOAT;
              $theInfo.theVar.fValue = $a.theInfo.theVar.fValue;
           }
        }
           ;

		   
/* description of the tokens */
FLOAT:'float';
INT:'int';
CHAR: 'char';

MAIN: 'main';
VOID: 'void';
IF: 'if';
ELSE: 'else';
FOR: 'for';
PRINTF: 'printf';
LITERAL : '"''%'(.)*'"';

//RelationOP: '>' |'>=' | '<' | '<=' | '==' | '!=';

Identifier:('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*;
Integer_constant:'0'..'9'+;
Floating_point_constant:'0'..'9'+ '.' '0'..'9'+;

STRING_LITERAL
    :  '"' ( EscapeSequence | ~('\\'|'"') )* '"'
    ;

WS:( ' ' | '\t' | '\r' | '\n' ) {$channel=HIDDEN;};
COMMENT:'/*' .* '*/' {$channel=HIDDEN;};


fragment
EscapeSequence
    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    ;
