defmodule TeslaMate.HTTP do
  require Logger

  # === 新增：将官方地址定义为常量，并集中管理 NOMINATIM_API_HOST 逻辑 ===
  @official_nominatim "https://nominatim.openstreetmap.org"

  @spec nominatim_api_host() :: binary
  defp nominatim_api_host do
    case System.get_env("NOMINATIM_API_HOST") do
      nil ->
        @official_nominatim

      "" ->
        Logger.warning("[nominatim] NOMINATIM_API_HOST is empty -> fallback to official")
        @official_nominatim

      url ->
        uri = URI.parse(url)

        cond do
          is_nil(uri.scheme) or uri.scheme == "" ->
            Logger.warning("[nominatim] invalid NOMINATIM_API_HOST: missing scheme in #{inspect(url)} -> fallback")
            @official_nominatim

          is_nil(uri.host) or uri.host == "" ->
            Logger.warning("[nominatim] invalid NOMINATIM_API_HOST: missing host in #{inspect(url)} -> fallback")
            @official_nominatim

          true ->
            Logger.info("[nominatim] use API host #{url}")
            url
        end
    end
  end
  # === 新增逻辑结束 ===

  def pools do
    nominatim_proxy =
      case build_proxy_opts_from_env("NOMINATIM_PROXY") do
        {:ok, opts} -> opts
        {:none, _} -> []
        {:error, _} -> []
      end

    # 使用 NOMINATIM_API_HOST（若合法则为自建地址，否则回退到官方）
    base = nominatim_api_host()

    # 保持原始语义：仅当使用官方地址时才拼接 NOMINATIM_PROXY（作为 HTTP 代理）
    nominatim_pool_opts =
      if base == @official_nominatim do
        [size: 3] ++ nominatim_proxy
      else
        [size: 3]
      end

    %{
      System.get_env("TESLA_API_HOST", "https://owner-api.teslamotors.com") => [
        size: System.get_env("TESLA_API_POOL_SIZE", "10") |> String.to_integer()
      ],
      base => nominatim_pool_opts,
      "https://api.github.com" => [size: 1],
      :default => [size: System.get_env("HTTP_POOL_SIZE", "5") |> String.to_integer()]
    }
  end

  @pool_timeout System.get_env("HTTP_POOL_TIMEOUT", "10000") |> String.to_integer()

  @spec build_proxy_opts_from_env(binary) :: {:ok, keyword} | {:none, []} | {:error, []}
  defp build_proxy_opts_from_env(var) do
    url = System.get_env(var)
    Logger.info("[proxy] read #{var}=#{inspect(url)}")

    case url do
      nil ->
        Logger.info("[proxy] #{var} unset -> fallback: no proxy")
        {:none, []}

      _ ->
        uri = URI.parse(url)

        cond do
          uri.scheme != "http" ->
            Logger.warning(
              "[proxy] #{var}=#{inspect(url)} unsupported scheme=#{inspect(uri.scheme)} (only http). fallback: no proxy"
            )

            {:error, []}

          is_nil(uri.host) or uri.host == "" ->
            Logger.warning(
              "[proxy] #{var}=#{inspect(url)} invalid URI: missing host. fallback: no proxy"
            )

            {:error, []}

          not is_integer(uri.port) ->
            Logger.warning(
              "[proxy] #{var}=#{inspect(url)} invalid URI: missing/invalid port. fallback: no proxy"
            )

            {:error, []}

          true ->
            opts = [conn_opts: [proxy: {:http, uri.host, uri.port, []}]]
            Logger.info("[proxy] set http proxy host=#{uri.host} port=#{uri.port}")
            {:ok, opts}
        end
    end
  end

  def child_spec(_arg) do
    Finch.child_spec(name: __MODULE__, pools: pools())
  end

  def get(url, opts \\ []) do
    {headers, opts} =
      opts
      |> Keyword.put_new(:pool_timeout, @pool_timeout)
      |> Keyword.pop(:headers, [])

    Finch.build(:get, url, headers, nil)
    |> Finch.request(__MODULE__, opts)
  end

  def post(url, body \\ nil, opts \\ []) do
    {headers, opts} =
      opts
      |> Keyword.put_new(:pool_timeout, @pool_timeout)
      |> Keyword.pop(:headers, [])

    Finch.build(:post, url, headers, body)
    |> Finch.request(__MODULE__, opts)
  end
end
