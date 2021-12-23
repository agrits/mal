defmodule Collie.Core do
  alias Collie.{Printer, Reader}
  alias Collie.Atom, as: CAtom

  @erlang_fs [
    :+,
    :-,
    :*,
    :/,
    :<,
    :>,
  ]

  def namespace do

    wrapped =
      %{
        "=" => &equal/2,
        "list?" => &is_list/1,
        "empty?" => &empty?/1,
        "count" => &count/1,
        "to_list" => &to_list/1,
        "<=" => &Kernel.<=/2,
        ">=" => &Kernel.>=/2,
        "read-string" => &Reader.read_str/1,
        "slurp" => &slurp/1,
        "cwd" => &File.cwd!/0,
        "atom" => &CAtom.new/1,
        "atom?" => &CAtom.atom?/1,
        "deref" => &CAtom.deref/1,
        "reset!" => &CAtom.reset!/2
      }
      |> wrap_all()

    not_wrapped = %{
      "list" => fn args -> args end,
      "pr-str" => &pr_str/1,
      "prn" => &prn/1,
      "str" => &str/1,
      "println" => &println/1,
      "swap!" => &CAtom.swap!/1
    }

    wrapped
    |> Map.merge(not_wrapped)
    |> Map.merge(from_erlang(@erlang_fs))
  end

  defp pr_str(args) do
    args
    |> Enum.map(&Printer.pr_str/1)
    |> Enum.join(" ")
  end

  defp prn(args) do
    pr_str(args)
    |> IO.puts()

    nil
  end

  defp println(args) do
    args
    |> Enum.map(&Printer.pr_str(&1, false))
    |> Enum.join(" ")
    |> IO.puts()

    nil
  end

  def str(args) do
    args
    |> Enum.map(& Printer.pr_str(&1, false))
    |> Enum.join()
  end

  defp empty?({:vector, []}), do: true
  defp empty?({:vector, _}), do: false
  defp empty?([]), do: true
  defp empty?(l) when is_list(l), do: false

  defp to_list(s) when is_bitstring(s) do
    String.to_charlist(s)
  end

  defp count(l) do
    case l do
      {:vector, sth} when is_list(sth) -> length(sth)
      sth when is_list(sth) -> length(sth)
      _ -> 0
    end
  end

  defp from_erlang(functions) do
    :erlang.module_info(:exports)
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(fn name -> name in functions end)
    |> Enum.map(fn name -> {Atom.to_string(name), fn args -> apply(:erlang, name, args) end} end)
    |> Enum.into(%{})
  end

  defp wrap_all(ns) do
    ns
    |> Map.to_list()
    |> Enum.map(fn {key, value} -> {key, wrap(value)} end)
    |> Enum.into(%{})
  end

  defp wrap(function) do
    fn args -> apply(function, args) end
  end

  defp vectors_to_list_deep({:vector, ast}), do: vectors_to_list_deep(ast)
  defp vectors_to_list_deep(ast) when is_list(ast), do: Enum.map(ast, &vectors_to_list_deep/1)
  defp vectors_to_list_deep(ast) when is_map(ast) do
    ast
    |> Enum.map(fn {key, value} -> {key, vectors_to_list_deep(value)} end)
    |> Enum.into(%{})
  end
  defp vectors_to_list_deep(ast), do: ast

  defp equal(a, b), do: vectors_to_list_deep(a) == vectors_to_list_deep(b)

  defp slurp(filename) do
    File.read!(filename)
  end
end
