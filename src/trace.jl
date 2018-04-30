struct Trace
  seen::Set
  warn
end

Trace(w) = Trace(Set(), w)

isprimitive(f) = f isa Core.Builtin || f isa Core.IntrinsicFunction

const ignored_methods = [@which((1,2)[1])]

@primitive ctx::Trace function (f::Any)(args...)
  C, T = DynamicCall(f, args...), typeof.((f, args...))
  (T ∈ ctx.seen || isprimitive(f) ||
    method(C) ∈ ignored_methods ||
    method(C).module ∈ [Core, Core.Inference]) && return f(args...)
  push!(ctx.seen, T)
  result = overdub(ctx, f, args...)
  analyse((a...) -> ctx.warn(Warning(a...)), C)
  return result
end

trace(w, f) = overdub(Trace(w), f)

warntrace(f) = trace(warning_printer(), f)

function warnings(f)
  warnings = Warning[]
  trace(w -> push!(warnings, w), f)
  return warnings
end

macro trace(ex)
  :(warntrace(() -> $(esc(ex))))
end
