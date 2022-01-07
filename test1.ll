; === prologue ====
declare dso_local i32 @printf(i8*, ...)

@.strf = private unnamed_addr constant [4 x i8] c"%f\0A\00", align 1
@.strd = private unnamed_addr constant [4 x i8] c"%d\0A\00", align 1

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
%t1 = alloca i32, align 4
%t2 = alloca i32, align 4
store i32 3, i32* %t2
%t3 = load i32, i32* %t2
%t4 = add nsw i32 %t3, 198
store i32 %t4, i32* %t1
%t5 = load i32, i32* %t1
%t6 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 %t5)
%t7 = load i32, i32* %t2
%t8 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 %t7)

; === epilogue ===
ret i32 0
}
