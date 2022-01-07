; === prologue ====
declare dso_local i32 @printf(i8*, ...)

@.strf = private unnamed_addr constant [4 x i8] c"%f\0A\00", align 1
@.strd = private unnamed_addr constant [4 x i8] c"%d\0A\00", align 1

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
%t1 = alloca i32, align 4
store i32 40, i32* %t1
store i32 30, i32* %t0
%t2 = load i32, i32* %t1
%t3 = icmp sge i32 %t2, 20
br i1 %t3, label %l0, label %l1
l0:				;
%t4 = load i32, i32* %t1
%t5 = add nsw i32 %t4, 1
store i32 %t5, i32* %t1
%t6 = load i32, i32* %t1
%t7 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 %t6)
br label %lend
l1:				;
%t8 = load i32, i32* %t0
%t9 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strd, i64 0, i64 0), i32 %t8)
br label %lend
lend:				;
ret i32 0

; === epilogue ===
ret i32 0
}
