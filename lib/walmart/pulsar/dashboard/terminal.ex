defmodule Walmart.Pulsar.Dashboard.Terminal do
  @moduledoc """
  Functions to handle termcap style screen rendering.

  This is currently hard-coded for xterm.
  """

  def cursor_invisible(), do: <<0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x6c>> # civis

  def save_cursor_position, do: <<0x1b, 0x37>> # sc

  def cursor_up(lines) do
  if lines > 0 do
    <<0x1b, 0x5b>> <> to_string(lines) <> <<0x41>>
  else
    ""
  end
end

  def leftmost_column(), do: <<0x1b, 0x5b, 0x31, 0x47>> # hpa 0

  def clear_to_end(), do: <<0x1b, 0x5b, 0x4b>> # el

  def restore_cursor_position(), do: <<0x1b, 0x38>> # rc

  def cursor_visible(), do: <<0x1b, 0x5b, 0x3f, 0x31, 0x32, 0x6c, 0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x68>> # cnorm

end
