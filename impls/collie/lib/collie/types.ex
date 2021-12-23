defmodule Collie.Types do
  def vector(ast) do
    {:vector, ast}
  end

  def list(ast) do
    {:list, ast}
  end

  def symbol(ast) do
    {:symbol, ast}
  end
end
