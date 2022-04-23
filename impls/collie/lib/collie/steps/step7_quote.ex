defmodule Collie.Steps.Step7Quote do
  alias Collie.{Env, Printer, Reader, Types}

  defp read(s), do: Reader.read_str(s)

  def eval_ast({:vector, ast}, env), do: eval_ast(ast, env) |> Types.vector()

  def eval_ast({:symbol, _} = key, env) do
    Env.get(env, key)
  end

  def eval_ast(ast, env) when is_list(ast) do
    Enum.map(ast, fn x -> eval(x, env) end)
  end

  def eval_ast(ast, env) when is_map(ast) do
    ast
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> {k, eval(v, env)} end)
    |> Enum.into(%{})
  end

  def eval_ast(ast, _env) do
    ast
  end

  defp exec_file(filename, env) do
  end

  defp bootstrap(args, env) do
    Env.set(env, {:symbol, "eval"}, fn [ast] -> eval(ast, env) end)

    """
    (def! not (fn* (a) (if a false true)))
    """
    |> rep(env)

    """
    (def! load-file (fn* [f] (eval (read-string (str "(do " (slurp f) "\nnil)"))))))
    """
    |> rep(env)

    case args do
      [] ->
        set_argv([], env)

      [filename | argv] ->
        set_argv(argv, env)
        rep("(eval (load-file #{inspect(filename)}))", env)
        exit(:normal)
    end
  end

  def eval(ast, env) when is_list(ast) do
    case ast do
      [] ->
        ast

      [{:symbol, "def!"}, {:symbol, _} = name_ast, body] ->
        do_def(name_ast, body, env)

      [{:symbol, "let*"}, bindings, ast] ->
        do_let(bindings, ast, env)

      [{:symbol, "do"} | rest] ->
        do_do(rest, env)

      [{:symbol, "fn*"}, binds, exprs] ->
        do_fn(binds, exprs, env)

      [{:symbol, "if"}, condition, if_true, if_false] ->
        do_if(condition, if_true, if_false, env)

      [{:symbol, "if"}, condition, if_true] ->
        do_if(condition, if_true, env)

      [{:symbol, "quote"}, ast] ->
        ast

      [{:symbol, "quasiquote"}, ast] ->
        do_quasiquote(ast)

      _ ->
        [f | args] = eval_ast(ast, env)
        apply(f, [args])
    end
  end

  def eval(ast, env), do: eval_ast(ast, env)

  defp do_def({:symbol, _} = name_ast, body, env) do
    eval(body, env)
    |> tap(&Env.set(env, name_ast, &1))
  end

  defp do_let({:vector, bindings}, ast, env), do: do_let(bindings, ast, env)

  defp do_let(bindings, ast, env) do
    inner_env = Env.new(env)

    bindings
    |> Enum.chunk_every(2, 2, [])
    |> Enum.each(fn [key, value] -> Env.set(inner_env, key, eval(value, inner_env)) end)

    eval(ast, inner_env)
  end

  defp do_do([first | _tail] = exprs, env) do
    exprs
    |> Enum.reduce(first, fn ast, _ -> eval(ast, env) end)
  end

  defp do_fn({:vector, binds}, exprs, env), do: do_fn(binds, exprs, env)

  defp do_fn(binds, exprs, env) do
    fn params ->
      inner_env = Env.new(env)
      set_bindings(inner_env, binds, params)
      eval(exprs, inner_env)
    end
  end

  defp do_if(condition, if_true, if_false, env) do
    case eval(condition, env) do
      v when v in [false, nil] -> eval(if_false, env)
      _ -> eval(if_true, env)
    end
  end

  defp do_if(condition, if_true, env) do
    do_if(condition, if_true, nil, env)
  end

  defp do_quasiquote([{:symbol, "unquote"}, ast | _]), do: ast

  defp do_quasiquote({:symbol, _} = ast), do: [Types.symbol("quote"), ast]

  defp do_quasiquote(ast) when is_map(ast), do: [Types.symbol("quote"), ast]

  defp do_quasiquote([]), do: []

  defp do_quasiquote([head | tail]) do
    case head do
      [{:symbol, "splice-unquote"}, second | _] ->
        [Types.symbol("concat"), do_quasiquote(tail)]

      _ ->
        [Types.symbol("cons"), do_quasiquote(head), do_quasiquote(tail)]
    end
  end

  defp do_quasiquote(ast) do
    ast
  end

  defp print(exp), do: Printer.pr_str(exp)

  defp rep(str, env) do
    str
    |> read
    |> eval(env)
    |> print
  catch
    e -> "#{inspect(e)}"
  end

  defp set_bindings(env, [{:symbol, "&"}, rest], values) do
    Env.set(env, rest, values)
  end

  defp set_bindings(env, [bindings_head | bindings_tail], [values_head | values_tail]) do
    Env.set(env, bindings_head, values_head)
    set_bindings(env, bindings_tail, values_tail)
  end

  defp set_bindings(_env, [], []) do
  end

  def start(args) do
    env = Env.new()
    bootstrap(args, env)
    loop(env)
  end

  def loop(env) do
    try do
      IO.gets("user> ")
      |> String.trim("\n")
      |> rep(env)
      |> IO.puts()
    rescue
      e -> IO.puts(inspect({:error, inspect(e)}))
    end

    loop(env)
  end

  defp set_argv(argv, env) do
    Env.set(env, {:symbol, "*ARGV*"}, argv)
  end
end
