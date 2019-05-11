defmodule Adler32Checksum do
  @moduledoc """
  Computes an adler32 checksum for the file at the given path
  """

  @blocksize 12 * 1024 * 1024

  def compute(path) do
    with {:ok, file} <- File.open(path, [:binary, :read]),
         checksum <- build_checksum(file),
         :ok <- File.close(file) do
      {:ok, checksum}
    else
      error -> error
    end
  end

  defp build_checksum(file, asum \\ 0) do
    case IO.binread(file, @blocksize) do
      :eof -> asum
      {:error, error} -> {:error, error}
      data -> build_checksum(file, :erlang.adler32(asum, data))
    end
  end
end
