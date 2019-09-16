const should_not_warn = Set{Function}()

"""
    @should_not_warn function foo(x)
      ...
    end

Add `foo` to the list of functions in which no warnings may occur (checkd by `@check`).
"""
macro should_not_warn(expr)
  quote
    fun = $(esc(expr))
    push!(should_not_warn, fun)
    fun
  end
end

"""
    check(f::Function; nowarn=[], except=[], kwargs...)

Run Traceur on `f`, and throw an error if any warnings occur inside functions
tagged with `@should_not_warn` or specified in `nowarn`.

To throw an error if any warnings occur inside any functions, set
`nowarn=:all`.

To throw an error if any warnings occur inside any functions EXCEPT for a
certain set of functions, set `nowarn=:allexcept` and list the exceptions in
the `except` variable, i.e. set `except=[f, g, h, ...]`
"""
function check(f; nowarn=Any[], except=Any[], kwargs...)
  if nowarn isa Symbol
    _nowarn = Any[]
    if nowarn == :all
      _nowarn_all = true
      _nowarn_allexcept = false
    elseif nowarn == :allexcept
      _nowarn_all = false
      _nowarn_allexcept = true
    else
      throw(ArgumentError(":$(nowarn) is not a valid value for nowarn"))
    end
  else
    _nowarn = nowarn
    _nowarn_all = false
    _nowarn_allexcept = false
  end
  failed = false
  wp = warning_printer()
  result = trace(f; kwargs...) do warning
    ix = findfirst(warning.stack) do call
      _nowarn_all || call.f in should_not_warn || call.f in _nowarn || (_nowarn_allexcept && !(call.f in except))
    end
    if ix != nothing
      tagged_function = warning.stack[ix].f
      message = "$(warning.message) (called from $(tagged_function))"
      warning = Warning(warning.call, warning.line, message, warning.stack)
      wp(warning)
      failed = true
    end
  end
  @assert !failed "One or more warnings occured inside functions tagged with `@should_not_warn` or specified with `nowarn`"
  result
end

"""
    @check fun(args...) nowarn=[] except=[] maxdepth=typemax(Int)

Run Traceur on `fun`, and throw an error if any warnings occur inside functions
tagged with `@should_not_warn` or specified in `nowarn`.

To throw an error if any warnings occur inside any functions, set
`nowarn=:all`.

To throw an error if any warnings occur inside any functions EXCEPT for a
certain set of functions, set `nowarn=:allexcept` and list the exceptions in
the `except` variable, i.e. set `except=[f, g, h, ...]`
"""
macro check(expr, args...)
  quote
      check(() -> $(esc(expr)); $(map(esc, args)...))
    end
end
