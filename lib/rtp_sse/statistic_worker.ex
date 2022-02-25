defmodule RTP_SSE.StatisticWorker do

  use GenServer
  require Logger

  ## Server callbacks

  @impl true
  def start_link(_opts) do
    state = %{execution_times: [], crashes_nr: 0}
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    reset_stats_loop()
    {:ok, state}
  end

  @impl true
  def handle_cast({:reset_stats_loop}, state) do
    if length(state.execution_times) > 0 do
      first = percentile(state.execution_times, 75)
      second = percentile(state.execution_times, 85)
      third = percentile(state.execution_times, 95)
      Logger.info(
        "[StatisticWorker #{inspect(self())}] Percentile stats 75%=#{first} | 85%=#{second} | 95%=#{third} [#{
          state.crashes_nr
        } CRASHES/5sec]"
      )
    end
    reset_stats_loop()
    {:noreply, %{execution_times: [], crashes_nr: 0}}
  end

  @impl true
  def handle_cast({:add_execution_time, time}, state) do
    {:noreply, %{execution_times: Enum.concat(state.execution_times, [time]), crashes_nr: state.crashes_nr}}
  end

  @impl true
  def handle_cast({:add_worker_crash}, state) do
    {:noreply, %{execution_times: state.execution_times, crashes_nr: state.crashes_nr + 1}}
  end

  ## Private

  defp reset_stats_loop() do
    pid = self()
    spawn(
      fn ->
        Process.sleep(5000)
        GenServer.cast(pid, {:reset_stats_loop})
      end
    )
  end

  @doc """
    Compute percentile for a given list and percentile value respectively
  """
  defp percentile([], _), do: nil
  defp percentile([x], _), do: x

  defp percentile(list, n) when is_list(list) and is_number(n) do
    s = Enum.sort(list)
    r = n / 100.0 * (length(list) - 1)
    f = :erlang.trunc(r)
    lower = Enum.at(s, f)
    upper = Enum.at(s, f + 1)
    res = lower + (upper - lower) * (r - f)
    Float.ceil(res, 2)
  end


end