/***PROPRIETARY_STATEMENT********************************************
 *
 * IBM CONFIDENTIAL
 *
 * OCO SOURCE MATERIALS
 *
 * 5650-ZOS
 *
 * COPYRIGHT IBM CORP. 2020
 *
 * THE SOURCE CODE FOR THIS PROGRAM IS NOT PUBLISHED OR OTHERWISE
 * DIVESTED OF ITS TRADE SECRETS, IRRESPECTIVE OF WHAT HAS BEEN
 * DEPOSITED WITH THE U.S. COPYRIGHT OFFICE.
 *
 * STATUS = HBB77D0
 *
 ********************************************************************
 *
 */

#ifndef STICKIFY_H_
#define STICKIFY_H_

#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/SmallVector.h"
extern "C" {
#include "third_party/zdnn-lib/zdnn/zdnn.h"
}

/// Set information for a pre transformed descriptor.
void set_info_pre_transformed_desc(zdnn_tensor_desc *pre_tfrmd_desc,
    zdnn_data_layouts layout, zdnn_data_types type,
    llvm::ArrayRef<int64_t> shape);

/// Generate a transformed descriptor.
zdnn_status generate_transformed_desc(
    const zdnn_tensor_desc *pre_tfrmd_desc, zdnn_tensor_desc *tfrmd_desc);

/// Generate a concatenated transformed descriptor.
zdnn_status generate_transformed_desc_concatenated(
    const zdnn_tensor_desc *pre_tfrmd_desc, zdnn_concat_info concat_info,
    zdnn_tensor_desc *tfrmd_desc);

/// Initialize a ztensor.
void init_ztensor(zdnn_tensor_desc *pre_tfrmd_desc,
    zdnn_tensor_desc *tfrmd_desc, zdnn_ztensor *ztensor);

/// Allocate ztensor buffer
zdnn_status allochelper_ztensor_alloc(zdnn_ztensor *ztensor);

/// Deallocate ztensor buffer
void allochelper_ztensor_free(zdnn_ztensor *ztensor);

/// Converts the input tensor to the supported stick format for execution by
/// zDNN operations.
///
///
/// Typical usage:
/// \code
///   status = stickify(&ztensor, &data);
///   status = stickify(&ztensor, &forget, &input, &cell, &output);
/// \endcode
///
/// \param tensor Pointer to zdnn_ztensor
/// \param ... 1, 3, or 4 data buffers to be stickified. (1 for most, 3 for ZRH,
///            4 for FICO)
///
/// \returns ZDNN_OK
///          ZDNN_INVALID_FORMAT
///          ZDNN_INVALID_LAYOUT
///          ZDNN_INVALID_TYPE
///          ZDNN_INVALID_BUFFER
///          ZDNN_INVALID_STATE
///          ZDNN_CONVERT_FAILURE
///
zdnn_status stickify(zdnn_ztensor *ztensor, ...);

#endif /* STICKIFY_H_ */
