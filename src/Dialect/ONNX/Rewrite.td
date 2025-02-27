// SPDX-License-Identifier: Apache-2.0

//===---- ONNXRewrite.td - Pattern Match Rewriting for ONNX --*- tablegen -===//
//
// Copyright 2019 The IBM Research Authors.
//
// =============================================================================
//
// Defines language-specific pattern match optimizations for ONNX using
// Declarative Rewrite Rules (DRR) specified using TableGen records.
//
//===----------------------------------------------------------------------===//

#ifndef ONNX_REWRITE
#define ONNX_REWRITE

#ifndef OP_BASE
include "src/Dialect/ONNX/ONNX.td"
#endif // OP_BASE

/// Note: The DRR definition used for defining patterns is shown below:
///
/// class Pattern<
///    dag sourcePattern, list<dag> resultPatterns,
///    list<dag> additionalConstraints = [],
///    dag benefitsAdded = (addBenefit 0)
/// >;

//===----------------------------------------------------------------------===//
// Common utility functions.
//===----------------------------------------------------------------------===//

// Create a DenseElementsAttr from a float attribute and an element type.
def createDenseElementsAttrFromFloatAttr : NativeCodeCall<
  "onnx_mlir::createDenseElementsAttrFromFloatAttr($_builder, $0.getType().cast<ShapedType>().getElementType(), $1)">;

// Create a DenseElementsAttr from the shape of the type of a value.
def createDenseElementsAttrFromShape : NativeCodeCall<
  "onnx_mlir::createDenseElementsAttrFromShape($_builder, $0)">;

// Create a DenseElementsAttr from the size of the type of a value.
def createDenseElementsAttrFromSize : NativeCodeCall<
  "onnx_mlir::createDenseElementsAttrFromSize($_builder, $0)">;

// If '$1' is not NoneType, do subtraction '$1 - $2'.
// Otherwise, take the negative of '$2'.
def subtractOrNeg: NativeCodeCall<
  "onnx_mlir::subtractOrNeg($_builder, $0.getDefiningOp()->getLoc(), $1, $2)">;

// Get the rank of the given value.
def getRankOf :
	NativeCodeCall<"$0.getType().cast<ShapedType>().getRank()">;

// Create an ArrayAttr of IntergerAttr(s) of [$0].
def createArrayAttrOf : NativeCodeCall<
  "onnx_mlir::createArrayAttrOfNToM($_builder, $0, $0)">;

// Create an ArrayAttr of IntergerAttr(s) of values in [1, N-1].
def createArrayAttrOfOneToRankOf : NativeCodeCall<
  "onnx_mlir::createArrayAttrOfOneToN($_builder, $0.getType().cast<ShapedType>().getRank() - 1)">;

// Create an ArrayAttr of IntergerAttr(s) of values in [1, N-2].
def createArrayAttrOfOneToRankOfExclusive : NativeCodeCall<
  "onnx_mlir::createArrayAttrOfOneToN($_builder, $0.getType().cast<ShapedType>().getRank() - 2)">;

// Create an ArrayAttr of IntergerAttr(s) of values in [2, rank - 1].
def createArrayAttrOfTwoToRankOf : NativeCodeCall<
  "onnx_mlir::createArrayAttrOfNToM($_builder, 2, $0.getType().cast<ShapedType>().getRank() - 1)">;

def ONNXConstantOpNormalize: NativeCodeCall<
  "onnx_mlir::normalizeConstantOp($_builder, $0, $1)">;

def AttributeIsNotNull :
  Constraint<CPred<" ($_self) ">, "Attribute is null">;

def IsDenseElementsAttr :
  Constraint<And<[CPred<" ($_self) ">, 
                  CPred<" ($_self).isa<DenseElementsAttr>()">
                 ]>, "Attribute is not a DenseElementsAttr">;

// Intended to check whether there is at least one not-Null the attributes
// However, the current table gen can only support max 4 parameters
// Multiple rules are used instead of one rule
def AttributesNotAllNull :
  Constraint<Neg<And<[CPred<"($0)">, CPred<" ($1) ">, CPred<" ($2) ">]>>,
  "Attributes are not null">;

def GetNullAttr : NativeCodeCall<"Attribute()">;

def GetNullFloatAttr : NativeCodeCall<"FloatAttr()">;

def GetNullIntegerAttr : NativeCodeCall<"IntegerAttr()">;

def GetNullStringAttr : NativeCodeCall<"StringAttr()">;

def GetNullArrayAttr :  NativeCodeCall<"ArrayAttr()">;

// Check whether an ArrayAttr contains non-zero values or not.
def HasNonZeroInArrayAttr: Constraint<CPred<"hasNonZeroInArrayAttr($_self)">,
                                       "has non-zero elements">;

// Check the rank of a value is greater than a given integer.
class HasRankGT<int rank> :
  Constraint<CPred<"$0.getType().isa<ShapedType>() && "
                   "$0.getType().cast<ShapedType>().hasRank() && "
                   "$0.getType().cast<ShapedType>().getRank() > " # rank>>;

// Check the rank of a value is of a given integer.
class HasRankOf<int rank> :
  Constraint<CPred<"$0.getType().isa<ShapedType>() && "
                   "$0.getType().cast<ShapedType>().hasRank() && "
                   "$0.getType().cast<ShapedType>().getRank() == " # rank>>;

def HaveSameLastDim: Constraint<
  CPred<"onnx_mlir::hasShapeAndRank($0) && onnx_mlir::hasShapeAndRank($1) && "
        "($0.getType().cast<RankedTensorType>().getShape()"
        "[$0.getType().cast<RankedTensorType>().getRank() - 1] == "
        "$1.getType().cast<RankedTensorType>().getShape()"
        "[$1.getType().cast<RankedTensorType>().getRank() - 1])">,
  "Two tensors have the same last dimension">;

class HaveSameDim<int dim>: Constraint<
  CPred<"onnx_mlir::hasShapeAndRank($0) && onnx_mlir::hasShapeAndRank($1) && "
        "$0.getType().cast<RankedTensorType>().getShape()[" # dim # "] != -1 && "
        "($0.getType().cast<RankedTensorType>().getShape()[" # dim # "] =="
        "$1.getType().cast<RankedTensorType>().getShape()[" # dim # "])">,
  "Two tensors have the same specified dimension">;

def GetUnitAttr: NativeCodeCall<"$_builder.getUnitAttr()">;

def HasOneUse : Constraint<CPred<"$0.hasOneUse()">>;

def HasNoneType : Constraint<CPred<"$0.getType().isa<NoneType>()">>;

def NotNoneType : Constraint<CPred<"!($0.getType().isa<NoneType>())">>;

def HasShapeAndRank : Constraint<CPred<"onnx_mlir::hasShapeAndRank($0)">>;

def HasSameElementType : Constraint<
    CPred<"($0.getType().dyn_cast<ShapedType>().getElementType() == "
          "$1.cast<::mlir::TypeAttr>().getValue())">,
    "has same element type">;

def HaveSameElementType : Constraint<
    CPred<"($0.getType().dyn_cast<ShapedType>().getElementType() == "
          "$1.getType().dyn_cast<ShapedType>().getElementType())">,
    "has same element type">;

def HaveSameElementTypeBitWidth: Constraint<
    CPred<"($0.getType().dyn_cast<ShapedType>().getElementTypeBitWidth() == "
          "$1.getType().dyn_cast<ShapedType>().getElementTypeBitWidth())">,
    "has same element type bitwidth">;

def  ElementTypeIsNotUnsigned: Constraint<
    CPred<"!$_self.getType().dyn_cast<ShapedType>().getElementType().isUnsignedInteger()">,
    "element type is not unsigned int">;

def IsStaticShapeTensor:
  Constraint<
    CPred<
      "$_self.getType().cast<::mlir::ShapedType>().hasStaticShape()">,
    "hasStaticShape">;

def AreTheSameAxisArray: Constraint<
    CPred<"onnx_mlir::AreTheSameAxisArray("
          "(onnx_mlir::hasShapeAndRank($0) ? $0.getType().cast<ShapedType>().getRank() : 0),"
          "$1, $2)">,
    "Two axis arrays are the same">;

def HasSpecifiedConstantShape: Constraint<
    CPred<"onnx_mlir::HasSpecifiedConstantShape($0, $1)">,
          "Has the specified constant shape">;

def IsFromONNXConstantOp: Constraint<
    CPred<"llvm::dyn_cast_or_null<ONNXConstantOp>($0.getDefiningOp())">,
    "Is a value from ONNXConstantOp">;

def IsNotFromONNXConstantOp: Constraint<
    CPred<"!(llvm::dyn_cast_or_null<ONNXConstantOp>($0.getDefiningOp()))">,
    "Is a value not from ONNXConstantOp">;

def IsFromONNXConstantOpWithDenseElementsAttr: Constraint<
    And<[CPred<" isa<ONNXConstantOp>($_self.getDefiningOp()) ">,
         CPred<" onnx_mlir::getONNXConstantOp($_self).valueAttr().isa<DenseElementsAttr>() ">
        ]>, "Value is not a ONNXConstantOp with a DenseElementsAttr">;

def AreTheSameConstantOpDenseAttr: Constraint<
    CPred<"onnx_mlir::AreTheSameConstantOpDenseAttr($_builder,"
          "(onnx_mlir::hasShapeAndRank($0) ? $0.getType().cast<ShapedType>().getRank() : 0),"
          "$1, $2)">,
    "Two ConstantOps have the same dense attribute values">;

class AllDimsFromAxisToEndAre<int axis, int val>: Constraint<
    CPred<"llvm::all_of("
            "ArrayRef<int64_t>($_self.getType().cast<ShapedType>().getShape().begin() + " # axis # ","
            "                  $_self.getType().cast<ShapedType>().getShape().end()),"
            "[](int64_t val) { return (val == " # val # ");})">,
    "All dimensions from axis to the end are val">;

class RankXMinusRankYIs<int diff>: Constraint<
    CPred<"($0.getType().cast<ShapedType>().getRank() "
          " - $1.getType().cast<ShapedType>().getRank() == " # diff # ")">,
    "X' rank is greater than Y's rank diff units">;

def TransposeVariadicInput: NativeCodeCall<
  "onnx_mlir::transposeVariadicInput($_builder, $_loc, $0, $1)">;

// Check whether two variables are equal.
def Equal: Constraint<CPred<"$0 == $1">, "are equal">;

class EqualString<string s> : Constraint<CPred<"$0 == \"" # s # "\"">>;

//===----------------------------------------------------------------------===//
// Pattern-Match and Rewrite
//===----------------------------------------------------------------------===//

def GemmAlpha : NativeCodeCall<"$_builder.getF32FloatAttr(1.0)">;
def GemmBeta : NativeCodeCall<"$_builder.getF32FloatAttr(1.0)">;
def GemmTransA : NativeCodeCall<"IntegerAttr::get($_builder.getIntegerType(64, /*isSigned=*/true), APInt(64, 0, /*isSigned=*/true))">;
def GemmTransB : NativeCodeCall<"IntegerAttr::get($_builder.getIntegerType(64, /*isSigned=*/true), APInt(64, 0, /*isSigned=*/true))">;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXAddOp
//===----------------------------------------------------------------------===//

// onnx.add(onnx.matmul(%X, %Y), %Z) = onnx.Gemm(%X, %Y, %Z)
def MulAddToGemmOptPattern : Pat<(ONNXAddOp (ONNXMatMulOp:$res $m1, $m2), $m3),
                                 (ONNXGemmOp $m1, $m2, $m3, (GemmAlpha), (GemmBeta), (GemmTransA), (GemmTransB)),
                                 [(HasOneUse $res), (HasRankOf<2> $m1), (HasRankOf<2> $m2)]>;

// onnx.add(onnx.Gemm(%X, %Y, None), %Z) = onnx.Gemm(%X, %Y, %Z)
def FuseGemmFollowedByAddition : Pat<(ONNXAddOp (ONNXGemmOp:$res $m1, $m2, $none, $alpha, $beta, $transA, $transB), $bias),
                                     (ONNXGemmOp $m1, $m2, $bias, $alpha, $beta, $transA, $transB),
                                     [(HasOneUse $res), (HasNoneType $none)]>;

//===----------------------------------------------------------------------===//
// This is to fuse the composition: 'Add o Conv' into 'Conv' if the other input
// of Add is a constant, by adding the constant to 'b' of 'Conv':
//
// We have:
//   (Conv)      z = w * x + b
//   (Add)       y = z + constant
//
// which corresponds to the following computation:
//   y = w * x + new_b
// where
//   new_b = b + constant
//
// The shape of 'constant' must be compatible with that of 'b'
//===----------------------------------------------------------------------===//

def NormalizeAddPattern: Pat<
  (ONNXAddOp $x, $y),
  (ONNXAddOp $y, $x),
  [(IsFromONNXConstantOp $x), (IsNotFromONNXConstantOp $y)]
>;

def FuseAddConvNullBiasPattern: Pat<
  (ONNXAddOp:$res
    (ONNXConvOp
       $x, $w, $b, $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
    (ONNXConstantOp:$y $_, $denseAttr, $_, $_, $_, $_, $_, $_)),
  (ONNXConvOp
     $x, $w,
     // new_b
     (ONNXSqueezeV11Op
        $y,
        (createArrayAttrOfOneToRankOf $y)),
     // unchanged operands and attributes.
     $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
  [(HasNoneType $b),
   (AttributeIsNotNull:$denseAttr),
   (AllDimsFromAxisToEndAre<1, 1>:$y),
   (RankXMinusRankYIs<1> $res, $y)]
>;

def FuseAddConvPattern: Pat<
  (ONNXAddOp:$res
    (ONNXConvOp
       $x, $w, $b, $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
    (ONNXConstantOp:$y $_, $denseAttr, $_, $_, $_, $_, $_, $_)),
  (ONNXConvOp
     $x, $w,
     // new_b
     (ONNXAddOp
        $b,
        (ONNXSqueezeV11Op
           $y,
           (createArrayAttrOfOneToRankOf $y))),
     // unchanged operands and attributes.
     $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
  [(NotNoneType $b),
   (AttributeIsNotNull:$denseAttr),
   (AllDimsFromAxisToEndAre<1, 1>:$y),
   (RankXMinusRankYIs<1> $res, $y)]
>;

//===----------------------------------------------------------------------===//
// This is to fuse the composition: 'Mul o Conv' into 'Conv' if the other input
// of Mul is a constant, by multipling constant to 'w' of 'Conv':
//
// We have:
//   (Conv)      z = i * w + b
//   (Mul)       y = z x c      (where c is a constant)
//
// which corresponds to the following computation:
//   y = i * new_w + b
// where
//   new_w = w x c
//
// The shape of 'c' must be compatible with that of 'w'
//===----------------------------------------------------------------------===//

def NormalizeMulPattern: Pat<
  (ONNXMulOp $x, $y),
  (ONNXMulOp $y, $x),
  [(IsFromONNXConstantOp $x), (IsNotFromONNXConstantOp $y)]
>;

def FuseMulConvNullBiasPattern: Pat<
  (ONNXMulOp:$res
    (ONNXConvOp
       $x, $w, $b, $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
    (ONNXConstantOp:$y $_, $denseAttr, $_, $_, $_, $_, $_, $_)),
  (ONNXConvOp
     $x,
     // new_w
     (ONNXMulOp $w, (ONNXUnsqueezeV11Op $y, (createArrayAttrOf(getRankOf $y)))),
     // unchanged operands and attributes.
     $b, $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
  [(HasNoneType $b),
   (IsDenseElementsAttr:$denseAttr),
   (IsFromONNXConstantOpWithDenseElementsAttr:$w),    
   (HaveSameElementType $w, $y),       // multiplier and Conv weight must have the same element type.      
   (HasRankGT<1> $w),                  // rank of $w must be at least 2.  
   (RankXMinusRankYIs<1> $w, $y),      // rank($y) must be equal to rank($w)-1.
   (HaveSameDim<0> $w, $y),            // the first dimension of $w and $y must be equal.
   (AllDimsFromAxisToEndAre<1, 1>:$y)] // all dimensions of $y must be 1 except for the first one.
>;

// TODO add pattern for non-null bias with contraints:
// - bias must be have rank equal to 1 and 
// - bias element data type must be the same as mul constant
// - bias dimension (0) must be equal to mul constant dim(0)
// codegen is different too (look it up in onnx-runtime)

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXIdentityOp
//===----------------------------------------------------------------------===//

// ONNX_Op (onnx.Identity (%X)) = ONNX_Op (%X)
def IdentityEliminationPattern : Pat<(ONNXIdentityOp $arg),
                                     (replaceWithValue $arg)>;

// y, mask = onnx.Dropout(x) -> y, mask = x, none
def DropoutEliminationPattern : Pattern<(ONNXDropoutOp $arg, $arg1, $arg2, $ratio),
  [(replaceWithValue $arg), (ONNXConstantOp (GetNullAttr), (GetUnitAttr), 
   (GetNullAttr), (GetNullAttr), (GetNullAttr), (GetNullAttr), (GetNullAttr), 
   (GetNullAttr))]>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXCastOp
//===----------------------------------------------------------------------===//

// ONNX_Op (onnx.Cast (%X, $type)) = ONNX_Op (%X)
def CastEliminationPattern : Pat<
	(ONNXCastOp $arg, $type),
	(replaceWithValue $arg),
  [(HasSameElementType $arg, $type)]>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXTransposeOp
//===----------------------------------------------------------------------===//

// Combine transposes.
def CreateCombinedTransposedPattern :
   NativeCodeCall<"onnx_mlir::CombinedTransposePattern($_builder, $0, $1)">;

def IsIdentityPermuteAttribute :
  Constraint<CPred<"onnx_mlir::IsIdentityPermuteVector($_self)">,
    "has identity permute vector">;

def FuseTransposePattern:  Pat<
  // Transpose of a transpose.
  (ONNXTransposeOp (ONNXTransposeOp $v, $p1), $p2),
  // Transpose with combined pattern.
  (ONNXTransposeOp $v, (CreateCombinedTransposedPattern $p1, $p2))>;

def RemoveIdentityTransposePattern:  Pat<
  // Transpose with an identity pattern (e.g. {0, 1, 2, 3}).
  (ONNXTransposeOp $val, $p),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that we have indeed a identity transpose pattern.
  [(IsIdentityPermuteAttribute:$p)]>;

def GetIndexOfAxisInPerm: NativeCodeCall<
  "onnx_mlir::getIndexOfAxisInPerm($_builder, $0, $1)"
>;

def ProducedByTransposeOp: Constraint<
  CPred<"onnx_mlir::areProducedByTransposeOp($_self)">,
  "all values are produced by ONNXTransposeOp"
>;

// Do transpose on concat's inputs instead of output in order to propagate
// transpose operations together, which allows more chance for transpose fusion.
// Do this only when all inputs are produced by transpose operations.
def SwapTransposeConcatPattern: Pat<
  (ONNXTransposeOp:$res (ONNXConcatOp $inputs, $axis), $perm),
  (ONNXConcatOp (TransposeVariadicInput $inputs, $perm),
                (GetIndexOfAxisInPerm $perm, $axis)),
  [(ProducedByTransposeOp:$inputs)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXReshapeOp
//===----------------------------------------------------------------------===//

def FuseReshapePattern:  Pat<
  // Reshape of a reshape.
  (ONNXReshapeOp (ONNXReshapeOp $v, $s1), $s2),
  // Remove the first reshape op.
  (ONNXReshapeOp $v, $s2)>;

def RemoveIdentityReshapePattern:  Pat<
  // Remove an identity pattern. Input tensor already has the specified shape.
  (ONNXReshapeOp $val, $shape),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that val has the specified shape.
  [(HasSpecifiedConstantShape $val, $shape)]>;

def GetReturnTypeForMatMulOpND2D: NativeCodeCall<
  "onnx_mlir::getReturnTypeForMatMulOpND2D($0, $1)"
>;

def SwapReshapeMatMulPattern: Pattern<
 // If the input of Reshape is suitable for the next MatMul, use the input directly
 // for MatMul. In other words, swapping Reshape and MatMul.
 // This rule will put reshape ops together, then the reshape fusion rule can be applied.
 // TODO: Support dynamic dimensions.
 (ONNXMatMulOp:$res2 (ONNXReshapeOp:$res1 $A, $_), $B),
 [(ONNXReshapeOp (ONNXMatMulOp $A, $B, (returnType (GetReturnTypeForMatMulOpND2D $A, $B))),
                 (ONNXConstantOpFromDenseAttr (createDenseElementsAttrFromShape $res2)))],
 [(HasRankGT<2> $A), (HasRankOf<2> $res1), (HasRankOf<2> $B), // A is reshaped to 2D.
  (HaveSameLastDim $A, $res1), // The last dim of A is unchanged by reshape.
  (IsStaticShapeTensor:$res2)  // $res2 has static dims in order to create ReshapeOp.
 ]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXSqueezeOp
//===----------------------------------------------------------------------===//

/// Combine squeeze and unsqueeze.
/// Squeeze {axes = [a, b, c]} (Unsqueeze {axes = [a, b, c]} (%X)) = %X
def RemoveSqueezeUnsqueezePattern:  Pat<
  // Squeeze and the unsqueeze with the same axes.
  (ONNXSqueezeOp (ONNXUnsqueezeOp $val, $u_axes), $s_axes),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that both ops use the same `axes`.
  [(AreTheSameConstantOpDenseAttr $val, $u_axes, $s_axes),
   (IsFromONNXConstantOp $u_axes), (IsFromONNXConstantOp $s_axes)]>;

/// Combine squeeze and unsqueeze.
/// Squeeze {axes = [a, b, c]} (Unsqueeze {axes = [a, b, c]} (%X)) = %X
def RemoveSqueezeV11UnsqueezeV11Pattern:  Pat<
  // Squeeze and the unsqueeze with the same axes.
  (ONNXSqueezeV11Op (ONNXUnsqueezeV11Op $val, $u_axes), $s_axes),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that both ops use the same `axes`.
  [(AreTheSameAxisArray $val, $u_axes, $s_axes)]>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXUnsqueezeOp
//===----------------------------------------------------------------------===//

/// Combine unsqueeze and squeeze.
/// Unsqueeze {axes = [a, b, c]} (Squeeze {axes = [a, b, c]} (%X)) = %X
def RemoveUnsqueezeSqueezePattern:  Pat<
  // Squeeze and the unsqueeze with the same axes.
  (ONNXUnsqueezeOp (ONNXSqueezeOp:$res $val, $s_axes), $u_axes),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that both ops use the same `axes`.
  [(AreTheSameConstantOpDenseAttr $res, $u_axes, $s_axes),
   (IsFromONNXConstantOp $u_axes), (IsFromONNXConstantOp $s_axes)]>;

/// Combine unsqueeze and squeeze.
/// Unsqueeze {axes = [a, b, c]} (Squeeze {axes = [a, b, c]} (%X)) = %X
def RemoveUnsqueezeV11SqueezeV11Pattern:  Pat<
  // Squeeze and the unsqueeze with the same axes.
  (ONNXUnsqueezeV11Op (ONNXSqueezeV11Op:$res $val, $s_axes), $u_axes),
  // Remove the transpose.
  (replaceWithValue $val),
  // Check that both ops use the same `axes`.
  [(AreTheSameAxisArray $res, $u_axes, $s_axes)]>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXBatchNormOp
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// This is to fuse the composition: 'BatchNorm o Conv' into 'Conv'
// by deriving new 'w' and 'b' for 'Conv':
//
// We have:
//   (Conv)      z = w * x + b
//   (BatchNorm) y = scale * (z - mean) / sqrt(var + eps) + bias
//
// which corresponds to the following computation:
//   y = w_ * x + b_
// where
//   w_ = scale * w / sqrt(var + eps)
//   b_ = B + scale * (b - mean) / sqrt(var + eps)
//
// Hence, we rewrite:
//   onnx.BatchNormalizationInferenceMode(
//       onnx.Conv(x, w, b),
//       scale, B, mean, var
//   ) {eps = ...}
//
// as:
//    onnx.Conv(x, w_, b_)
//
//    where
//      w_ = scale * w / sqrt(var + eps)
//      b_ = B + scale * (b - mean) / sqrt(var + eps)
//
//===----------------------------------------------------------------------===//

def FuseBatchNormInferenceModeConvPattern: Pat<
  (ONNXBatchNormalizationInferenceModeOp:$res
    (ONNXConvOp $x, $w, $b,
                $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
    $scale, $B, $mean, $var, $epsilon, $momentum),
  (ONNXConvOp
     $x,
     // w_
     (ONNXMulOp
        $w,
        (ONNXUnsqueezeV11Op
           (ONNXDivOp:$coefficientW
              $scale,
              (ONNXSqrtOp
                 (ONNXAddOp
                    $var,
                    (ONNXConstantOpFromDenseAttr
                       (createDenseElementsAttrFromFloatAttr $res, $epsilon))))),
           (createArrayAttrOfOneToRankOf $w))),
     // b_
     (ONNXAddOp
        $B,
        (ONNXMulOp
           $coefficientW,
           (subtractOrNeg $res, $b, $mean))),

     $auto_pad, $dilation, $group, $kernel_shape, $pads, $strides),
     [], (addBenefit 1)
>;

//===----------------------------------------------------------------------===//
// This is to rewrite BatchNorm into 'x * a + b'
//
// We have:
//   (BatchNorm) y = scale * (x - mean) / sqrt(var + eps) + bias
//                 = x * a + b
//
// where
//   a = scale / sqrt(var + eps)
//   b = bias - mean * a
//
// In inference mode, 'scale', 'mean', 'var', 'eps', and 'bias' are expected to
// be constants. Thus, 'a' and 'b' would be constants after constant propagation.
//
//===----------------------------------------------------------------------===//

def RewriteBatchNormInferenceModeConvPattern1: Pat<
  (ONNXBatchNormalizationInferenceModeOp:$res
    $x, $scale, $bias, $mean, $var, $epsilon, $_),
  (ONNXAddOp
     // x * a
     (ONNXMulOp
        $x,
        (ONNXUnsqueezeV11Op
           (ONNXDivOp:$a
              $scale,
              (ONNXSqrtOp
                 (ONNXAddOp
                    $var,
                    (ONNXConstantOpFromDenseAttr
                       (createDenseElementsAttrFromFloatAttr $res, $epsilon))))),
           (createArrayAttrOfOneToRankOfExclusive $x))),
     // b
     (ONNXUnsqueezeV11Op
       (ONNXSubOp $bias, (ONNXMulOp $mean, $a)),
       (createArrayAttrOfOneToRankOfExclusive $x))),
  [(HasRankGT<2> $x)], (addBenefit 0)
>;

// Special case of BatchNorm whose input shape is [N]. In this case, 'scale',
// 'bias', 'mean', and 'var' will have shape of [1], according to ONNXBatchNorm
// decription: https://github.com/onnx/onnx/blob/main/docs/Operators.md#inputs-12.
// Thus, we need not unsqueeze intermediate results.
def RewriteBatchNormInferenceModeConvPattern2: Pat<
  (ONNXBatchNormalizationInferenceModeOp:$res
    $x, $scale, $bias, $mean, $var, $epsilon, $_),
  (ONNXAddOp
     // x * a
     (ONNXMulOp
        $x,
        (ONNXDivOp:$a
           $scale,
           (ONNXSqrtOp
              (ONNXAddOp
                 $var,
                 (ONNXConstantOpFromDenseAttr
                    (createDenseElementsAttrFromFloatAttr $res, $epsilon)))))),
     // b
     (ONNXSubOp $bias, (ONNXMulOp $mean, $a))),
  [(HasRankOf<1> $x)], (addBenefit 0)
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXShapeOp
//===----------------------------------------------------------------------===//

// TODO: this rules may need to be updated once ShapeOp has start/end.
def ShapeToConstantPattern: Pat<
     (ONNXShapeOp $A),
     (ONNXConstantOp
        (GetNullAttr), (createDenseElementsAttrFromShape $A),
        (GetNullFloatAttr), (GetNullArrayAttr), (GetNullIntegerAttr),
        (GetNullArrayAttr), (GetNullStringAttr), (GetNullArrayAttr)
     ),
     [(IsStaticShapeTensor:$A)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXSizeOp
//===----------------------------------------------------------------------===//

def SizeToConstantPattern: Pat<
     (ONNXSizeOp $A),
     (ONNXConstantOp
        (GetNullAttr), (createDenseElementsAttrFromSize $A),
        (GetNullFloatAttr), (GetNullArrayAttr), (GetNullIntegerAttr),
        (GetNullArrayAttr), (GetNullStringAttr), (GetNullArrayAttr)
     ),
     [(IsStaticShapeTensor:$A)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXGlobalAveragePoolOp
//===----------------------------------------------------------------------===//

// Rewrite GlobalAveragePool using ReduceMean.
def GlobalAveragePoolPattern: Pat<
  (ONNXGlobalAveragePoolOp $x),
  (ONNXReduceMeanOp $x, (createArrayAttrOfTwoToRankOf $x), (GetNullAttr))
>;

// Rewrite GlobalMaxPool using ReduceMax.
def GlobalMaxPoolPattern: Pat<
  (ONNXGlobalMaxPoolOp $x),
  (ONNXReduceMaxOp $x, (createArrayAttrOfTwoToRankOf $x), (GetNullAttr))
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXDepthToSpaceOp
//===----------------------------------------------------------------------===//

// Combine DepthToSpace and SpaceToDepth.
// DepthToSpace (SpaceToDepth (%X)) = %X
def RemoveDepthToSpaceSpaceToDepthPattern : Pat<
        (ONNXDepthToSpaceOp (ONNXSpaceToDepthOp $v, $bs1), $bs2, $mode),
        (replaceWithValue $v),
        [(Equal $bs1, $bs2), (EqualString<"CRD"> $mode)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXSpaceToDepthOp
//===----------------------------------------------------------------------===//

// Combine SpaceToDepth and DepthToSpace.
// DepthToSpace (SpaceToDepth (%X)) = %X
def RemoveSpaceToDepthDepthToSpacePattern : Pat<
        (ONNXSpaceToDepthOp (ONNXDepthToSpaceOp $v, $bs1, $mode), $bs2),
        (replaceWithValue $v),
        [(Equal $bs1, $bs2), (EqualString<"CRD"> $mode)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXConstantOp
//===----------------------------------------------------------------------===//

def ConstantOpNormalizationPattern1: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $floatAttr),
   [(AttributeIsNotNull:$floatAttr)]
>;

def ConstantOpNormalizationPattern2: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $intAttr),
   [(AttributeIsNotNull:$intAttr)]
>;

def ConstantOpNormalizationPattern3: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $stringAttr),
   [(AttributeIsNotNull:$stringAttr)]
>;

def ConstantOpNormalizationPattern4: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $floatsAttr),
   [(AttributeIsNotNull:$floatsAttr)]
>;

def ConstantOpNormalizationPattern5: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $intsAttr),
   [(AttributeIsNotNull:$intsAttr)]
>;

def ConstantOpNormalizationPattern6: Pat<
   (ONNXConstantOp:$res $sparseAttr, $denseAttr, $floatAttr, $floatsAttr, $intAttr,
       $intsAttr, $stringAttr, $stringsAttr),
   (ONNXConstantOpNormalize $res, $stringsAttr),
   [(AttributeIsNotNull:$stringsAttr)]
>;

//===----------------------------------------------------------------------===//
// Canonicalization for ONNXLessOp
//===----------------------------------------------------------------------===//

def LessOpSameCastPattern: Pat<
   (ONNXLessOp (ONNXCastOp:$cast_a $a, $to1), (ONNXCastOp $b, $to2)),
   (ONNXLessOp $a, $b),
   [(HaveSameElementType $a, $b), (Equal $to1, $to2),
    (HaveSameElementTypeBitWidth $a, $cast_a),
    (ElementTypeIsNotUnsigned:$cast_a)]
>;

#endif // ONNX_REWRITE
