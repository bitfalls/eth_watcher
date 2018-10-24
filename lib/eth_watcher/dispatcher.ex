defmodule EthWatcher.Dispatcher do
  @base_url ""

  def dispatch(tx) when is_nil(tx), do: nil
  def dispatch(tx), do: post(tx)

  defp post(msg) do
    headers = [{"Content-Type", "application/json"}]

    with {:ok, payload} <- Poison.encode(msg),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.post(@base_url, payload, headers),
         {:ok, %{"result" => result}  } <- Poison.decode(body) do
      {:ok, result}
    end
  end

end