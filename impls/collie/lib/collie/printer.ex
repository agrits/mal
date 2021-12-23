defmodule Collie.Printer do

  def pr_str(ast, print_readably \\ true)

  def pr_str(ast, print_readable) when is_list(ast), do: pr_seq(ast, "(", ")", print_readable)

  def pr_str(ast, _) when is_function(ast), do: "#<function>"

  def pr_str({:symbol, name}, _), do: name

  def pr_str({:vector, ast}, print_readable), do: pr_seq(ast, "[", "]", print_readable)

  def pr_str({:atom, pid}, print_readable), do: "(atom #{pr_str(Collie.Atom.deref({:atom, pid}), print_readable)})"

  def pr_str(ast, print_readable) when is_map(ast) do
    ast
    |> Map.to_list()
    |> Enum.map(&Tuple.to_list/1)
    |> List.foldr([], &append(&1, &2))
    |> pr_seq("{", "}", print_readable)
  end

  def pr_str(ast, _) when is_number(ast) or is_boolean(ast), do: "#{ast}"

  def pr_str(nil, _), do: "nil"

  def pr_str(ast, _) when is_atom(ast), do: ":#{ast}"

  def pr_str(ast, true) when is_bitstring(ast), do: inspect(ast)

  def pr_str(ast, false) when is_bitstring(ast), do: ast

  defp pr_seq(ast, start_sep, end_sep, print_readable) do
    joined =
      ast
      |> Enum.map(& pr_str(&1, print_readable))
      |> Enum.join(" ")

    "#{start_sep}#{joined}#{end_sep}"
  end

  defp append(first, second) when is_list(first) and is_list(second) do
    first
    |> Enum.reverse()
    |> Enum.reduce(second, &[&1 | &2])
  end
end
