; === prologue ====
declare dso_local i32 @printf(i8*, ...)

@.strf = private unnamed_addr constant [4 x i8] c"%f\0A\00", align 1
@.strd = private unnamed_addr constant [4 x i8] c"%d\0A\00", align 1

define dso_local i32 @main()
{
%t0 = alloca float, align 4
%t1 = alloca float, align 4
%t2 = alloca i32, align 4
%t3 = alloca i32, align 4
store float 0x3fd99999a0000000, float* %t1
store float 0x3fe6666660000000, float* %t0
%t4 = load float, float* %t0
%t5 = fpext float %t4 to double
%t6 = fsub double %t5, 0.2
%t7 = fptrunc double %t6 to float
%t8 = fpext float %t7 to double
%t9 = fmul double 0.6, %t8
%t10 = fptrunc double %t9 to float
store float %t10, float* %t1
%t11 = load float, float* %t0
%t12 = load float, float* %t1
%t13 = fcmp oeq float %t11, %t12
br i1 %t13, label %l0, label %l1
l0:				;
%t14 = load float, float* %t0
%t15 = fpext float %t14 to double
%t16 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strf, i64 0, i64 0), double %t15)
br label %lend
l1:				;
%t17 = load float, float* %t1
%t18 = fpext float %t17 to double
%t19 = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.strf, i64 0, i64 0), double %t18)
br label %lend
lend:				;
ret i32 0

; === epilogue ===
ret i32 0
}
