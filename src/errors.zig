const std = @import("std");

pub const RenderError = error{
    MemoryAllocationError,
    TemplateBuildFailed,
    JSONSerializationError,
};
pub const ContextError = error{};
pub const ViewError = RenderError || ContextError;
