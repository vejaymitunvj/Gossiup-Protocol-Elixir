################################# START OF APP ######################################
#####################################################################################
##                                                                                 ##
## Description: The application module which accepts the commandline arguments     ##
##              and starts the supervisor                                          ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
#####################################################################################
defmodule GossipNetworkDeployer do
  def main(argv) do
    input = argv

    numString = input |> Enum.at(0)
    {numNodes, ""} = Integer.parse(numString, 10)

    if numNodes > 1 do
      topology = input |> Enum.at(1)

      algorithm = input |> Enum.at(2)

      numNodes =
        case {topology, numNodes} do
          {"randhoneycomb", numNodes} ->
            if numNodes < 12 do
              IO.puts("Please enter number of nodes greater than 12")
              System.halt(0)
            else
              numNodes
            end

          {"honeycomb", numNodes} ->
            if numNodes < 12 do
              IO.puts("Please enter number of nodes greater than 12")
              System.halt(0)
            else
              numNodes
            end

          {"3Dtorus", numNodes} ->
            cubeRoot = trunc(ceil(:math.pow(numNodes, 1 / 3)))

            numNodes =
              if numNodes != trunc(ceil(:math.pow(cubeRoot, 3))) do
                numNodes = trunc(ceil(:math.pow(cubeRoot, 3)))

                IO.puts(
                  "The given value is not a perfect cube, hence rounding it to the nearest cube value of #{
                    inspect(numNodes)
                  } for 3D Torus"
                )

                numNodes
              else
                numNodes
              end

            numNodes

          _ ->
            numNodes
        end

      ##### Algorith Check ####
      case algorithm do
        "gossip" ->
          GossipNodesMonitor.start_link([numNodes, 1, topology])

        "pushsum" ->
          GossipNodesMonitor.start_link([numNodes, 2, topology])

        _ ->
          IO.puts("Please enter the correct Algorithm : 'gossip' or 'pushsum' ")
      end
      else
      IO.puts("ENTER NODE VALUE ABOVE 0")
    end
  end
end

################################## END OF APP #######################################

#####################################################################################
##                                                                                 ##
## Description: The  actors template that monitors convergence                     ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
#####################################################################################
defmodule TopologyMap do
  def get(nodeList, topology) do
    map =
      case topology do
        "full" ->
          full(nodeList)

        "line" ->
          line(nodeList)

        "rand2D" ->
          rand2D(nodeList)

        "randhoneycomb" ->
          honeycomb(nodeList, "random")

        "honeycomb" ->
          honeycomb(nodeList, "normal")

        "3Dtorus" ->
          torus3D(nodeList)

        _ ->
          IO.puts("Incorrect topology. Please enter from the following choices:")
          IO.puts("full, line, rand2D, randhoneycomb, honeycomb, torus3D")
      end

    #### Now creating a map with the node pid as it's key and it's neigbors pid as
    ### it's value ###

    map
  end

  def full(nodeList) do
    numNodes = length(nodeList)

    neighborList =
      for i <- 1..numNodes do
        nodeList -- [Enum.at(nodeList, i - 1)]
      end

    map =
      Enum.reduce(1..numNodes, %{}, fn i, map ->
        # Enum Map start at 0
        Map.put(map, Enum.at(nodeList, i - 1), Enum.at(neighborList, i - 1))
      end)

    map
  end

  def line(nodeList) do
    sizeOfnodeList = length(nodeList)

    mappedNode = 1..sizeOfnodeList |> Stream.zip(nodeList) |> Enum.into(%{})

    Enum.reduce(1..sizeOfnodeList, %{}, fn nodeVal, returnMap ->
      neighboursVal =
        cond do
          nodeVal == 1 -> [2]
          nodeVal == sizeOfnodeList -> [sizeOfnodeList - 1]
          true -> [nodeVal - 1, nodeVal + 1]
        end

      #### generating and collecting neighbour PIDS ####
      retrieveNeighbourPids =
        Enum.map(neighboursVal, fn v ->
          {:ok, nodePid} = Map.fetch(mappedNode, v)
          nodePid
        end)

      #### creating the final maps with initial pid as key and neighbor pids as list of values ####
      {:ok, nodes} = Map.fetch(mappedNode, nodeVal)
      Map.put(returnMap, nodes, retrieveNeighbourPids)
    end)
  end

  def rand2D(nodeList) do
    numOfNodes = length(nodeList)
    valueList = Enum.to_list(1..numOfNodes)
    mappedNode = valueList |> Stream.zip(nodeList) |> Enum.into(%{})

    coordinateList =
      Enum.map(1..numOfNodes, fn _x ->
        x = :rand.uniform(100) / 100
        y = :rand.uniform(100) / 100
        [x, y]
      end)

    mapCoordinateNodesList = valueList |> Stream.zip(coordinateList) |> Enum.into(%{})

    # Enum.reduce(valueList,%{}, fn(nodeVal,returnMap)->

    Enum.reduce(valueList, %{}, fn x, returenMap ->
      {:ok, p1} = Map.fetch(mapCoordinateNodesList, x)

      val =
        Enum.map(valueList -- [x], fn y ->
          {:ok, p2} = Map.fetch(mapCoordinateNodesList, y)
          dis = findDistance(p1, p2)

          if dis <= 0.1 do
            {:ok, val1} = Map.fetch(mappedNode, y)
            val1
          end
        end)

      val = Enum.uniq(val)
      val = val -- [nil]

      {:ok, nodes} = Map.fetch(mappedNode, x)
      Map.put(returenMap, nodes, val)
    end)
  end

  def findDistance(p1, p2) do
    [x1, y1] = p1
    [x2, y2] = p2
    dx = (x2 - x1) |> :math.pow(2)
    dy = (y2 - y1) |> :math.pow(2)
    distance = :math.sqrt(dy + dx)
  end

  def selectLargestGroup(map) do
    [{len}, {node}] =
      Enum.at(Enum.sort(Enum.map(map, fn {k, v} -> [{length(v)}, {k}] end), &(&1 >= &2)), 0)

    {len, node}
  end

  ########################### Start Honey Comb random and Honey Comb Topology ###################################

  def honeycomb(nodeList, topology) do
    numOfNodes = length(nodeList)
    valueList = Enum.to_list(1..numOfNodes)
    mappedNode = valueList |> Stream.zip(nodeList) |> Enum.into(%{})

    Enum.reduce(valueList, %{}, fn nodeVal, returnMap ->
      neighboursVal =
        Enum.reduce(1..3, %{}, fn degree, addmap ->
          level = trunc(ceil(nodeVal / 6))

          if degree == 1 && nodeVal + 6 <= numOfNodes do
            Map.put(addmap, degree, nodeVal + 6)
          else
            if degree == 2 && nodeVal - 6 > 0 do
              Map.put(addmap, degree, nodeVal - 6)
            else
              if degree == 3 do
                nodeLvlVal = finalConnectCheck(level, nodeVal, numOfNodes)

                Map.put(addmap, degree, nodeLvlVal)
              else
                addmap
              end
            end
          end
        end)

      neighboursVal = Map.values(neighboursVal) -- [nil]

      neighboursVal =
        case topology do
          "random" ->
            neighboursVal ++ addRandomNode(neighboursVal, nodeVal, numOfNodes)

          _ ->
            neighboursVal
        end

      retrieveNeighbourPids =
        Enum.map(neighboursVal, fn v ->
          {:ok, nodePid} = Map.fetch(mappedNode, v)
          nodePid
        end)

      {:ok, nodes} = Map.fetch(mappedNode, nodeVal)
      Map.put(returnMap, nodes, retrieveNeighbourPids)
    end)
  end

  ########## Start adding random node for Random Honey Topology#########
  def addRandomNode(neighboursVal, nodeVal, numOfNodes) do
    randNode = :rand.uniform(numOfNodes)
    neighboursVal = neighboursVal ++ [nodeVal]

    if(Enum.member?(neighboursVal, randNode)) do
      addRandomNode(neighboursVal, nodeVal, numOfNodes)
    else
      [randNode]
    end
  end

  ########## End adding random node for Random Honey Topology#########
  ########## Start last set of connection for Honey Topology#########
  def finalConnectCheck(level, nodeVal, numOfNodes) do
    if rem(level, 2) != 0 do
      if rem(nodeVal, 6) > 1 do
        if rem(nodeVal, 2) == 0 and nodeVal + 1 <= numOfNodes do
          nodeVal + 1
        else
          nodeVal - 1
        end
      end
    else
      if rem(nodeVal, 2) == 0 do
        nodeVal - 1
      else
        if nodeVal + 1 <= numOfNodes do
          nodeVal + 1
        end
      end
    end
  end

  ########## End last set of connection for Honey Topology#########

  ########################### End Honey Comb random and Honey Comb Topology ###################################

  ############################### START OF 3D TORUS ##############################################
  def torus3D(nodeList) do
    numOfNodes = length(nodeList)
    valueList = Enum.to_list(1..numOfNodes)
    mappedNode = valueList |> Stream.zip(nodeList) |> Enum.into(%{})
    noLayers = trunc(ceil(:math.pow(numOfNodes, 1 / 3)))

    Enum.reduce(1..numOfNodes, %{}, fn nodeVal, returnMap ->
      layer = trunc(ceil(nodeVal / (noLayers * noLayers)))

      upperlimit = layer * noLayers * noLayers

      lowerlimit = (layer - 1) * noLayers * noLayers + 1

      neighboursVal =
        Enum.reduce(1..9, %{}, fn degree, addmap ->
          if degree == 1 && nodeVal - noLayers >= lowerlimit do
            Map.put(addmap, degree, nodeVal - noLayers)
          else
            if degree == 2 && nodeVal + noLayers <= upperlimit do
              Map.put(addmap, degree, nodeVal + noLayers)
            else
              if degree == 3 && rem(nodeVal, noLayers) != 1 && nodeVal - 1 > 0 do
                Map.put(addmap, degree, nodeVal - 1)
              else
                if degree == 4 && rem(nodeVal, noLayers) != 0 && nodeVal + 1 <= numOfNodes do
                  Map.put(addmap, degree, nodeVal + 1)
                else
                  if degree == 5 && nodeVal + noLayers * noLayers <= numOfNodes do
                    Map.put(addmap, degree, nodeVal + noLayers * noLayers)
                  else
                    if degree == 6 && nodeVal - noLayers * noLayers > 0 do
                      Map.put(addmap, degree, nodeVal - noLayers * noLayers)
                    else
                      if degree == 7 && (layer == 1 or layer == noLayers) do
                        lastconnect = (noLayers - 1) * (noLayers * noLayers)

                        if layer == 1 do
                          Map.put(addmap, degree, nodeVal + lastconnect)
                        else
                          Map.put(addmap, degree, nodeVal - lastconnect)
                        end
                      else
                        if degree == 8 &&
                             (rem(nodeVal, noLayers) == 0 or rem(nodeVal, noLayers) == 1) do
                          rightLeftconnect = noLayers - 1

                          if rem(nodeVal, noLayers) == 1 do
                            Map.put(addmap, degree, nodeVal + rightLeftconnect)
                          else
                            Map.put(addmap, degree, nodeVal - rightLeftconnect)
                          end
                        else
                          if degree == 9 &&
                               (nodeVal + (noLayers - 1) * noLayers <= upperlimit or
                                  nodeVal - (noLayers - 1) * noLayers >= lowerlimit) do
                            if nodeVal + (noLayers - 1) * noLayers <= upperlimit do
                              Map.put(addmap, degree, nodeVal + (noLayers - 1) * noLayers)
                            else
                              Map.put(addmap, degree, nodeVal - (noLayers - 1) * noLayers)
                            end
                          else
                            addmap
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end)

      neighboursVal = Map.values(neighboursVal)

      #### generating and collecting neighbour PIDS ####
      retrieveNeighbourPids =
        Enum.map(neighboursVal, fn v ->
          {:ok, nodePid} = Map.fetch(mappedNode, v)
          nodePid
        end)

      #### creating the final maps with initial pid as key and neighbor pids as list of values ####
      {:ok, nodes} = Map.fetch(mappedNode, nodeVal)
      Map.put(returnMap, nodes, retrieveNeighbourPids)
    end)
  end

  ############################### END OF 3D TORUS ##############################################

  def getMid(map) do
    nodeList = Map.keys(map)
    Enum.at(nodeList, div(length(nodeList), 2))
  end
end

#####################################################################################
##                                                                                 ##
## Description: The  actors template that monitors convergence                     ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
#####################################################################################

defmodule GossipNodesMonitor do
  @moduledoc """
      This is an actor that gossips a message until it has heard the message N times
  """
  use GenServer
  @self __MODULE__

  def start_link(argv) do
    GenServer.start_link(__MODULE__, argv, name: @self)
  end

  @impl true
  def init(argv) do
    [numNodes, algorithm, topology] = argv
    informedNodes = []
    terminatedNodes = []
    initTime = 0
    timeTakenInfo = 0
    timeTakenTerminate = 0
    timeTakenInfoOld = 0
    timeTakenTerminateOld = 0
    infoTimeChange = 0
    termTimeChange = 0
    # :ets.new(:informedNodes, [:set, :public, :named_table])
    #
    case algorithm do
      1 ->
        Process.send_after(self(), :startGossip, 0)

      2 ->
        Process.send_after(self(), :startPushSum, 0)

      _ ->
        IO.puts("Algorithm not implemented yet")
    end

    {:ok,
     {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
      timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
      termTimeChange}}
  end

  @impl true
  def handle_info(
        :startPushSum,
        {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
         timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
         termTimeChange}
      ) do
    nodeList = []
    #### We are spawning the nodes required for our network first ####
    nodeList =
      Enum.map(1..numNodes, fn num ->
        {:ok, node} =
          cond do
            true -> PushSumNodes.start_link(num)
          end

        node
      end)

    topologyMap = TopologyMap.get(nodeList, topology)

    #### INFORM THE NODES OF THEIR NEIGHBOURS ####
    for i <- 1..numNodes do
      node = Enum.at(nodeList, i - 1)
      {:ok, nodeNeighbor} = Map.fetch(topologyMap, node)
      setNeighbors(nodeNeighbor, node)
    end

    #### NOW START THE RUMOR FROM THE MID NODE ####
    midNode = TopologyMap.getMid(topologyMap)

    midNode =
      if topology == "rand2D" do
        {len, node} = TopologyMap.selectLargestGroup(topologyMap)
        node
      else
        midNode
      end

    initTime = System.monotonic_time(:millisecond)
    pushSum(midNode, {0, 0}, @self)

    {:noreply,
     {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
      timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
      termTimeChange}}
  end

  @impl true
  def handle_info(
        :startGossip,
        {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
         timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
         termTimeChange}
      ) do
    nodeList = []
    #### We are spawning the nodes required for our network first ####
    nodeList =
      Enum.map(1..numNodes, fn _num ->
        {:ok, node} =
          cond do
            true -> GossipNodes.start_link()
          end

        node
      end)

    topologyMap = TopologyMap.get(nodeList, topology)

    #### INFORM THE NODES OF THEIR NEIGHBOURS ####
    for i <- 1..numNodes do
      node = Enum.at(nodeList, i - 1)
      {:ok, nodeNeighbor} = Map.fetch(topologyMap, node)
      setNeighbors(nodeNeighbor, node)
    end

    #### NOW START THE RUMOR FROM THE MID NODE ####
    midNode = TopologyMap.getMid(topologyMap)
    initTime = System.monotonic_time(:millisecond)
    sendRumor(midNode, "Rumor has it", @self)

    {:noreply,
     {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
      timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
      termTimeChange}}
  end

  def setNeighbors(neighborList, node) do
    GenServer.cast(node, {:setNeighbor, neighborList})
  end

  def getNeighbors(node) do
    neighborList = GenServer.call(node, {:getNeighbor})
    neighborList
  end

  def sendRumor(node, rumor, sender) do
    GenServer.cast(node, {:heardRumor, rumor, sender})
  end

  def pushSum(node, {sVal, wVal}, sender) do
    GenServer.cast(node, {:pushSum, {sVal, wVal}, sender})
  end

  def informedNode(node) do
    GenServer.cast(@self, {:informedNode, node})
  end

  def terminatedNode(node) do
    GenServer.cast(@self, {:terminatedNode, node})
  end

  @impl true
  def handle_cast({:informedNode, node}, state) do
    {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
     timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
     termTimeChange} = state

    informedNodes = informedNodes ++ [node]

    state =
      {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
       timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
       termTimeChange}

    endTime = System.monotonic_time(:millisecond)
    timeTakenInfoOld = timeTakenInfo
    timeTakenInfo = endTime - initTime
    ##### CHECK IF ALL NODES HAVE RECEIVED THE MESSAGE; CONVERGENCE ####
    if length(informedNodes) == numNodes do
      if algorithm == 1 do
        IO.puts("Time taken to reach convergence: #{inspect(timeTakenInfo)} ms")
          System.halt(0)
      else
        #  IO.puts("Time taken for all nodes to get active: #{inspect(timeTakenInfo)} ms")
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:terminatedNode, node}, state) do
    {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
     timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
     termTimeChange} = state

    terminatedNodes = Enum.uniq(terminatedNodes ++ [node])

    state =
      {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
       timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
       termTimeChange}

    endTime = System.monotonic_time(:millisecond)
    timeTakenTerminateOld = timeTakenTerminate
    timeTakenTerminate = endTime - initTime
    ##### CHECK IF ALL NODES HAVE RECEIVED THE MESSAGE; CONVERGENCE ####
    state =
      if length(terminatedNodes) == numNodes do
        case algorithm do
          1 ->
            #    IO.puts("Time taken for all nodes to terminate: #{inspect(timeTakenTerminate)} ms")
            # For Gossip alone
            awaitDeath(node)

          2 ->
            IO.puts("Time taken to reach convergence: #{inspect(timeTakenTerminate)} ms")
        end

        state =
          {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
           timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
           termTimeChange}
      else
        # Process.send_after(self(), :spread, 0)
        terminated_count = length(terminatedNodes)
        informed_count = length(informedNodes)
        ratio_term_info = terminated_count / informed_count
        ratio_info_total = informed_count / numNodes
        num = length(Enum.uniq(informedNodes))
        spread_val = Float.round(ratio_info_total * 100, 4)

          # IO.puts(
          ##"WE ARE HERE #{inspect(timeTakenTerminate)} #{inspect(num)} #{inspect(terminated_count)} #{
          # inspect(ratio_term_info)
          #} #{inspect(ratio_info_total)} "
          #)

        if length(terminatedNodes) == length(informedNodes) || (length(terminatedNodes) != 0 && algorithm == 2) do
          IO.puts(
            "Maximum spread is #{inspect(spread_val)}% and convergence is reached at #{
              inspect(timeTakenTerminate)
            } ms"
          )
          System.halt(0)
        end

        if terminated_count != 0 && algorithm == 2 do
          IO.puts(
            "Time taken to reach convergence for PushSum: #{inspect(timeTakenTerminate)} ms"
          )

          System.halt(0)
        end

        state =
          {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
           timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
           termTimeChange}
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:wait, node}, state) do
    if Process.alive?(node) do
      awaitDeath(node)
    else
      System.halt(0)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:spread, state) do
    {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime, timeTakenInfo,
     timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld, infoTimeChange,
     termTimeChange} = state

    terminated_count = length(terminatedNodes)
    informed_count = length(informedNodes)
    ratio_term_info = terminated_count / informed_count
    ratio_info_total = informed_count / numNodes

    #  IO.puts(
    #  "WE ARE HERE #{inspect(timeTakenTerminate)} #{inspect(informed_count)} #{
    #    inspect(terminated_count)
    #  } #{inspect(ratio_term_info)} #{inspect(ratio_info_total)} "
    #)

    state =
      if informedNodes > terminatedNodes do
        state =
          if timeTakenTerminateOld != timeTakenTerminate do
            timeTakenTerminateOld = timeTakenTerminate
            termTimeChange = 0

            {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime,
             timeTakenInfo, timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld,
             infoTimeChange, termTimeChange}
          else
            termTimeChange = termTimeChange + 1

            state =
              {numNodes, topology, algorithm, informedNodes, terminatedNodes, initTime,
               timeTakenInfo, timeTakenTerminate, timeTakenInfoOld, timeTakenTerminateOld,
               infoTimeChange, termTimeChange}
          end

        if termTimeChange > 1 do
          ## NO change in the spread has happened
          case algorithm do
            1 ->
              #IO.puts("Time taken for all nodes to terminate: #{inspect(timeTakenTerminate)} ms")
               IO.puts("")
              #{:ok}

            2 ->
              IO.puts("Time taken to reach convergence: #{inspect(timeTakenTerminate)} ms")
          end

          #  System.halt(0)
        end

        state
      else
        state
      end

    Process.send_after(self(), :spread, 10000)
    {:noreply, state}
  end

  def awaitDeath(node) do
    Process.send_after(self(), {:wait, node}, 0)
  end
end

#####################################################################################
##                                                                                 ##
## Description: The  actors natedNodesmemplate that perform gossip                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
#####################################################################################

defmodule GossipNodes do
  @moduledoc """
      This is an actor that gossips a message until it has heard the message N times
  """
  use GenServer, restart: :transient

  def start_link() do
    state = %{count: 0, rumor: "", neighbor: []}
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def spreadRumor(node, rumor, sender) do
    GenServer.cast(node, {:heardRumor, rumor, sender})
  end

  @impl true
  def handle_call({:getNeighbor}, _from, state) do
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    {:reply, neighborList, state}
  end

  @impl true
  def handle_cast({:setNeighbor, neighborList}, state) do
    state = Map.put(state, :neighbor, neighborList)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:heardRumor, rumor, sender}, state) do
    {:ok, count} = Map.fetch(state, :count)
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    {:ok, prevRumor} = Map.fetch(state, :rumor)
    count = count + 1

    #### NOTIFY THE MONITOR THAT I HAVE HEARD THE RUMOR ###
    if prevRumor == "" do
      GossipNodesMonitor.informedNode(self())
      Process.send_after(self(), :spreadRumor, 0)
    end

    state = Map.put(state, :count, count)
    state = Map.put(state, :rumor, rumor)
    {:noreply, state}
  end

  def aliveNeighbors(nodeList) do
    Enum.filter(nodeList, fn node -> Process.alive?(node) end)
  end

  @impl true
  def handle_info(:spreadRumor, state) do
    {:ok, count} = Map.fetch(state, :count)
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    {:ok, rumor} = Map.fetch(state, :rumor)

    #### LET US UPDATE OUR NEIGHBOR LIST ####
    neighborList = aliveNeighbors(neighborList)
    state = Map.put(state, :neighbor, neighborList)

    if length(neighborList) >= 1 do
      if count <= 10 do
        ### RANDOMY SELECTING A NEIGHBOR TO SEND MESSAGE ###
        nextNode = Enum.at(neighborList, :rand.uniform(length(neighborList)) - 1)
        spreadRumor(nextNode, rumor, self())
        Process.send_after(self(), :spreadRumor, 1)
      else
        #      IO.puts("Stopping transmission for node #{inspect self()}")
        GossipNodesMonitor.terminatedNode(self())
        Process.send_after(self(), :terminate, 0)
      end
    else
      ### OUR PROCESS WAS STARTED BUT WE GOT NO ONE TO SEND OUR MESSAGE TO
      ### HENCE LET"S TERMINATE OURSELF
      GossipNodesMonitor.terminatedNode(self())
      #      IO.puts("forceful termination for #{inspect(self())}, count: #{inspect(count)}")
      Process.send_after(self(), :terminate, 0)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:terminate, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_, state) do
  end
end

#####################################################################################
##                                                                                 ##
## Description: The  nodes template that perform push sum aggregate calcualtion    ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
##                                                                                 ##
#####################################################################################

defmodule PushSumNodes do
  @moduledoc """
      This is an actor that gossips a message until it has heard the message N times
  """
  use GenServer, restart: :transient

  def start_link(sVal) do
    state = %{s: sVal, w: 1, sOld: 0, wOld: 1, neighbor: [], idle: 1, count: 0, flag: 0}
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def aliveNeighbors(nodeList) do
    Enum.filter(nodeList, fn node -> Process.alive?(node) end)
  end

  def pushSum(node, {sVal, wVal}, sender) do
    GenServer.cast(node, {:pushSum, {sVal, wVal}, sender})
  end

  @impl true
  def handle_info(:spreadSum, state) do
    {:ok, currentS} = Map.fetch(state, :s)
    {:ok, currentW} = Map.fetch(state, :w)
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    neighborList = aliveNeighbors(neighborList)
    state = Map.put(state, :neighbor, neighborList)

    if length(neighborList) >= 1 do
      ### RANDOMY SELECTING A NEIGHBOR TO SEND MESSAGE ###
      nextNode = Enum.at(neighborList, :rand.uniform(length(neighborList)) - 1)
      pushSum(nextNode, {currentS, currentW}, self())
      #     Process.send_after(self(), :spreadSum, 0)
    else
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:incCount, state) do
    {:ok, count} = Map.fetch(state, :count)
    count = count + 1
    state = Map.put(state, :count, count)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:pushSum, {s, w}, sender}, state) do
    {:ok, currentS} = Map.fetch(state, :s)
    {:ok, currentW} = Map.fetch(state, :w)
    {:ok, oldS} = Map.fetch(state, :sOld)
    {:ok, oldW} = Map.fetch(state, :wOld)
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    {:ok, idle} = Map.fetch(state, :idle)
    {:ok, count} = Map.fetch(state, :count)
    {:ok, flag} = Map.fetch(state, :flag)

    state =
      if(idle == 1) do
        ### INFORMING PARENT THAT THE MESSAGE HAS REACHED ME FIRST TIME ###
        GossipNodesMonitor.informedNode(self())
        idle = 0
        state = Map.put(state, :idle, idle)
        #        Process.send_after(self(), :spreadSum, 0)
        state
      else
        state
      end

    ratio = currentS / currentW
    newS = (currentS + s) / 2
    newW = (currentW + w) / 2

    newRatio = newS / newW
    currentRatio = currentS / currentW
    oldRatio = oldS / oldW

    currentChange = abs(newRatio - currentRatio)
    oldChange = abs(currentRatio - oldRatio)

    neighborList = aliveNeighbors(neighborList)
    state = Map.put(state, :neighbor, neighborList)
    state = Map.put(state, :s, newS)
    state = Map.put(state, :w, newW)
    state = Map.put(state, :sOld, currentS)
    state = Map.put(state, :wOld, currentW)

    state =
      if currentChange < :math.pow(10, -10) && oldChange < :math.pow(10, -10) do
        state =
          if flag == 0 do
            # GossipNodesMonitor.terminatedNode(self())
            state = Map.put(state, :flag, 1)
          else
            state
          end

        if count == 0 do
          # IO.puts("HERE 2 #{inspect(currentRatio)} #{inspect(newRatio)}")
          Process.send_after(self(), :terminate, 0)
        else
          Process.send_after(self(), :incCount, 0)
        end

        state
      else
        if length(neighborList) >= 1 do
          ### RANDOMY SELECTING A NEIGHBOR TO SEND MESSAGE ###
          nextNode = Enum.at(neighborList, :rand.uniform(length(neighborList)) - 1)
          pushSum(nextNode, {newS, newW}, self())
        else
          ### THIS NODE TERMINATES WITHOUT REACHING PUSH SUM STABILITY ###
          #        IO.puts("NODE #{inspect self} hasn't stablizied and has no neighbors to transmit hence terminating")
          if flag == 0 do
            #           GossipNodesMonitor.terminatedNode(self())
          end

          Process.send_after(self(), :terminate, 0)
        end

        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:setNeighbor, neighborList}, state) do
    state = Map.put(state, :neighbor, neighborList)
    {:noreply, state}
  end

  @impl true
  def handle_call({:getNeighbor}, _from, state) do
    {:ok, neighborList} = Map.fetch(state, :neighbor)
    {:reply, neighborList, state}
  end

  @impl true
  def handle_info(:terminate, state) do
    GossipNodesMonitor.terminatedNode(self())
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_, state) do
    ## ANY CLEANUP WORK
  end
end
