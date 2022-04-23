alias Collie.Types

defmodule Collie.Reader do
  @pattern ~r/[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*"?|;.*|[^\s\[\]{}('"`,;)]*)/

  def read_str(s) do
    case tokenize(s) do
      [] ->
        nil

      tokens ->
        read_form(tokens)
        |> elem(0)
    end
  end

  def tokenize(s) do
    @pattern
    |> Regex.scan(s, capture: :all_but_first)
    |> List.flatten()
    |> List.delete_at(-1)
    |> Enum.reject(fn token -> String.starts_with?(token, ";") end)
  end

  def read_form([next | tail], acc \\ []) do
    case next do
      "(" -> read_list(tail, acc)
      "{" -> read_hashmap(tail, acc)
      "[" -> read_vec(tail, acc)
      "'" -> create_quote(tail)
      "`" -> create_quasiquote(tail)
      "~" -> create_unquote(tail)
      "~@" -> create_splice_unquote(tail)
      "^" -> create_meta(tail)
      "@" -> create_deref(tail)
      _ -> {read_atom(next), tail}
    end
  end

  def read_list(tokens, acc \\ []) do
    read_seq(tokens, acc, ")")
  end

  def read_hashmap(tokens, acc \\ []) do
    {token, tail} = read_seq(tokens, acc, "}")

    m =
      token
      |> Enum.chunk_every(2)
      |> Enum.map(&List.to_tuple/1)
      |> Enum.into(%{})

    {m, tail}
  end

  def read_vec(tokens, acc \\ []) do
    {token, tail} = read_seq(tokens, acc, "]")
    {token |> Types.vector(), tail}
  end

  def read_charlist([next | tail], acc \\ []) do
    case next do
      "\"" -> {"\"#{acc}\"", tail}
      _ -> read_charlist(tail, [next | acc])
    end
  end

  defp create_quote(tokens), do: next_with_symbol(tokens, "quote")

  defp create_quasiquote(tokens), do: next_with_symbol(tokens, "quasiquote")

  defp create_unquote(tokens), do: next_with_symbol(tokens, "unquote")

  defp create_splice_unquote(tokens), do: next_with_symbol(tokens, "splice-unquote")

  defp create_deref(tokens), do: next_with_symbol(tokens, "deref")

  defp create_meta(tokens) do
    try do
      {first, tail} = read_form(tokens)
      {second, second_tail} = read_form(tail)
      {[Types.symbol("with-meta"), second, first], second_tail}
    rescue
      _ -> throw({:error, "Unexpected EOF"})
    end
  end

  defp next_with_symbol(tokens, symbol) do
    {next, tail} = read_form(tokens)
    {[Types.symbol(symbol), next], tail}
  end

  def read_seq([], _, _) do
    throw({:error, "Unexpected EOF."})
  end

  def read_seq([next | tail] = tokens, acc \\ [], end_sep) do
    case next == end_sep do
      true ->
        {Enum.reverse(acc), tail}

      false ->
        {token, tail} = read_form(tokens)
        read_seq(tail, [token | acc], end_sep)
    end
  end

  defp read_atom("true"), do: true
  defp read_atom("false"), do: false
  defp read_atom("nil"), do: nil
  defp read_atom(":" <> rest), do: String.to_atom(rest)

  defp read_atom(token) do
    cond do
      String.match?(token, ~r/^"(?:\\.|[^\\"])*"$/) ->
        token
        |> Code.string_to_quoted()
        |> elem(1)

      String.starts_with?(token, "\"") ->
        throw({:error, "expected '\"', got EOF"})

      true ->
        case Float.parse(token) do
          {f, ""} -> if round(f) == f, do: round(f), else: f
          _ -> Types.symbol(token)
        end
    end
  end
end
