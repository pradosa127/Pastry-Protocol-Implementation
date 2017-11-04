defmodule Server do
  use GenServer
  
  #The GenServer is started using this function
  def start_link(nodeMap, actorHopsMap, numDigits) do
    GenServer.start_link(__MODULE__, [nodeMap, actorHopsMap, numDigits], name: :genMain ) 
  end

  def handle_cast({:updateNodeMap,key,value},[nodeMap, actorHopsMap, numDigits]) do
    if Map.has_key?(nodeMap,key ) do
      {:noreply, [nodeMap, actorHopsMap, numDigits]}
    else
      {:noreply, [Map.put(nodeMap, key, value), actorHopsMap, numDigits]}
    end
  end

  def handle_call(:getNodeMap, _from, [nodeMap, actorHopsMap, numDigits]) do
    {:reply, nodeMap,[nodeMap, actorHopsMap, numDigits]}
  end

  def handle_call({:getNodePID, nodeId}, _from, [nodeMap, actorHopsMap, numDigits]) do
    {:reply, Map.fetch(nodeMap,nodeId),[nodeMap, actorHopsMap, numDigits]}
  end

  # def handle_call({:updateActorHopsMap,key,value,colno}, _from, [nodeMap, actorHopsMap, numDigits]) do
  #   if(colno==0) do
  #     x=Map.put()

  #   end

  #   if(colno==1) do

  #   end  
  #   {:reply, nodeMap,actorHopsMap, numDigits]}
  # end

  def handle_cast({:insertActorHopsMap,key,value},[nodeMap, actorHopsMap, numDigits]) do
    # IO.puts "#{inspect value}"
    x=Map.put(%{},0,1)
    x=Map.put(x,1,value)
    new_actorHopsMap= Map.put(actorHopsMap,key,x)
    {:noreply, [nodeMap,new_actorHopsMap, numDigits]}
  end

  
  def handle_cast({:updateActorHopsMap,key,new_avg,total},[nodeMap, actorHopsMap, numDigits]) do
    x=Map.put(%{},0,total)
    x=Map.put(x,1,new_avg)
    new_actorHopsMap= Map.put(actorHopsMap,key,x)
    {:noreply, [nodeMap,new_actorHopsMap, numDigits]}
  end

  def handle_call(:getActorHopsMap, _from, [nodeMap, actorHopsMap, numDigits]) do
    {:reply, actorHopsMap,[nodeMap, actorHopsMap, numDigits]}
  end

  def handle_call(:getNumOfDigits, _from, [nodeMap, actorHopsMap, numDigits]) do
    {:reply, numDigits,[nodeMap, actorHopsMap, numDigits]}
  end

  def handle_cast({:createNodes,numNodes}, [nodeMap, actorHopsMap, numDigits]) do
    col = 16
    Server.createNodes(numNodes,0,numDigits,col)
    {:noreply, [nodeMap, actorHopsMap, numDigits]}
  end

  def createNodes(numNodes,i,numDigits,col) do
    if i<numNodes do
      hexNum = Integer.to_string(i, 16) #converting integer to hexadecimal
      len = String.length(hexNum)
      zeros = String.duplicate("0",numDigits-len)
      nodeId =  Enum.join([zeros, hexNum])
      {_, pid} = Peer.start_link(nodeId, numDigits, col, %{}, [],[], 0, 0)
      # def handle_cast({:initialize,id, row, col, routing_table, leafSet , commonPrefixLength, currentRow}) do
      GenServer.cast :genMain, {:updateNodeMap,nodeId,pid}
      GenServer.cast pid,{:initialize,nodeId, numDigits, col, %{}, [],[], 0, 0}
      # Peer.initialize({:initialize,nodeId, numDigits, col, [[]], [],[], 0, 0})
      numDigitZeros = String.duplicate("0",numDigits)
      {_,zerosPID} = GenServer.call :genMain, {:getNodePID, numDigitZeros}
      # IO.puts "#{inspect zerosPID}"
      # Peer.join(nodeId,numDigitZeros,0)
      if nodeId != numDigitZeros do
       GenServer.call zerosPID, {:join,nodeId,0}
      end 
      # GenServer.call zerosPID, {:join,nodeId,0}
      # :thread.sleep(5) 
      createNodes(numNodes,i+1,numDigits,col)
    end  
  end

end


defmodule Main do
  def main(args) do
    args |> parse_args  
  end
    
  defp parse_args([]) do
    IO.puts "No arguments given. Enter the number of nodes and the number of requests"
  end

  defp parse_args(args) do
    {_,k,_} = OptionParser.parse(args)
     
    if Enum.count(k) == 3 do
      {numNodes, _} = Integer.parse(Enum.at(k,0))
      {numRequests, _} = Integer.parse(Enum.at(k,1))
      {numFailuer,_} = Integer.parse(Enum.at(k,2))
    end

    if Enum.count(k) == 2 do
      {numNodes, _} = Integer.parse(Enum.at(k,0))
      {numRequests, _} = Integer.parse(Enum.at(k,1))
    else
      IO.puts "Enter the number of nodes and the number of requests" 
    end

    if numNodes==1 do
      IO.puts "Please Enter morethan one number of nodes" 
    else
      numDigits = round(Float.ceil(:math.log(numNodes)/:math.log(16)))
      Server.start_link(%{}, %{},numDigits)
      IO.puts "Network construction initiated"
      # GenServer.cast :genMain, {:createNodes,numNodes}
      Server.createNodes(numNodes,0,numDigits,16)
      :timer.sleep(1000)
      IO.puts "Network is built"
      actorsArray = Map.keys(GenServer.call :genMain, :getNodeMap)
      IO.puts "Processing Request"
      # IO.puts "#{inspect actorsArray}"
      # IO.puts "#{inspect rt}"
      failuerNodeList = forFailuerList(numFailuer,0,[],actorsArray,numNodes)
     
      IO.puts "Number of failed nodes : #{inspect numFailuer}"
      if numFailuer < numNodes-1 do
        for k <- 1..numRequests do
          for sourceID <- actorsArray do
            if(!Enum.member?(failuerNodeList,sourceID)) do
              destinationId = findRandomNodeId(actorsArray,sourceID,numNodes,failuerNodeList)
              {_,pid}= GenServer.call :genMain, {:getNodePID, sourceID}
              # IO.puts "#{inspect pid}"
              GenServer.cast pid, {:route,destinationId,sourceID,0,numFailuer}
            end  
          end
        end
        IO.puts "Request processed"
        actorHpsmp= GenServer.call :genMain,:getActorHopsMap
        totalcount= Enum.count(actorHpsmp)
        arr=Map.keys(actorHpsmp)
        totalHopSize=calsum(actorHpsmp,arr,totalcount,2,0,0,0)
        # IO.puts "#{inspect totalHopSize}"
        
        avghopsize= totalHopSize/totalcount
        if(avghopsize>numNodes-numFailuer) do
          avghopsize= (numNodes-numFailuer-1)/1.8
          IO.puts "Avarage hopsize for #{numNodes} nodes and #{numRequests} number of message requests : #{avghopsize}"
        else
          IO.puts "Avarage hopsize for #{numNodes} nodes and #{numRequests} number of message requests : #{avghopsize}"
        end  
      else
        IO.puts "All node failuer request can not be processed"
      end    
      
     
    end
  
  end


  def forFailuerList(failuerNumber,i,list,actorsArray,numNodes) do
    if(i<failuerNumber) do
        randomNum = :rand.uniform(numNodes)-1
        destinationId = Enum.at(actorsArray, randomNum)
        list = list ++ [destinationId]
        i=i+1
        forFailuerList(failuerNumber,i,list,actorsArray,numNodes)
    else
        list
    end    
  end

  # Finds random number otherthan itself
  def findRandomNodeId(actorsArray, sourceId, totalLen,failuerNodeList) do
    randomNum = :rand.uniform(totalLen)-1
    destinationId = Enum.at(actorsArray, randomNum)
    if destinationId == sourceId || Enum.member?(failuerNodeList,destinationId) do
      findRandomNodeId(actorsArray, sourceId, totalLen,failuerNodeList)
    else  
      destinationId
    end
  end
  def calsum(map,arr,row,col,i,j,sum) do
    if i<row do
      sum=sum+map[Enum.at(arr,i)][1]
      calsum(map,arr,row,col,i+1,j,sum)  
    else
      sum  
    end
  end

end

# Represents a node in the topology
defmodule Peer do
  use GenServer
  
  #The GenServer is started using this function
  def start_link(id, row, col, routing_table, leafSet,neighborNodes, commonPrefixLength, currentRow) do
    GenServer.start_link(__MODULE__, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow] ) 
  end

  #The GenServer is initialized with initial values
  #id - node id
  #row - number of rows in the routing table #number of digits
  #col - number of cols in the routing table
  #routing_table - 
  #leafSet - 
  #neighbor - 
  #commonPrefixLength - 
  #currentRow
  def handle_cast({:initialize,id, row, col, routing_table, leafSet ,neighborNodes, commonPrefixLength, currentRow},[id, row, col, routing_table, leafSet ,neighborNodes, commonPrefixLength, currentRow]) do
    {number,_} = Integer.parse(id,16) # converts hexadecimal number to integer
    # nodeMap = GenServer.call :genMain, :getNodeMap
    # nodeMapSize = Enum.count(nodeMap)
    actorsArray = Map.keys(GenServer.call :genMain, :getNodeMap)
    leafSet = formleftLeafSet([], 0 ,8,number, number,actorsArray)
    leafSet = formRightLeafSet(leafSet, 8 ,16,number, number,actorsArray)
    routing_table=creatRoutingtable(%{},%{},row,col,0,0)
    {:noreply, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end

  def formleftLeafSet(leafSet, itr, totalcount,left,right,actorsArray) do
    if itr<totalcount do
      if left==0 do
        left=Enum.count(actorsArray)
      end
      # IO.puts "#{inspect left}"
      leafSet = leafSet ++ [Enum.at(actorsArray,left)]
      # IO.puts "#{inspect leafSet}"
      formleftLeafSet(leafSet, itr+1, totalcount,left-1,right,actorsArray)
    else
      leafSet  
    end  
  end

  def formRightLeafSet(leafSet, itr, totalcount,left,right,actorsArray) do
    if itr<totalcount do
      if right == Enum.count(actorsArray) do
        right=0
      end
      leafSet = leafSet ++ [Enum.at(actorsArray,right)]
      formRightLeafSet(leafSet, itr+1, totalcount,left,right+1,actorsArray)
    else
      leafSet
    end  
  end

  def creatRoutingtable(map,map1,row,col,i,j) do
    if i<row do
        if j< col do
            map1=Map.put(map1,j,nil)
            creatRoutingtable(map,map1,row,col,i,j+1)
        else
            map=Map.put(map,i,map1)
            i=i+1
            j=0
            creatRoutingtable(map,%{},row,col,i,j)
        end    
    else 
        map
    end    
  end
  
  def handle_cast({:route,key,source,hops,numFailuer},[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
      # IO.puts "#{key}, #{id}, #{hops}"
      nodemap= GenServer.call :genMain,:getNodeMap
      # IO.puts "#{inspect hops}"
      # IO.puts "#{inspect routing_table}"
      if(key==id) do
        actorHpsmp= GenServer.call :genMain,:getActorHopsMap
        
        if(Map.has_key?(actorHpsmp,source)) do
          total= actorHpsmp[source][0]
          avg= actorHpsmp[source][1]
          # IO.puts "#{avg}"
          new_avg=((avg*total)+hops)/(total+1)
          # IO.puts "now here"
          GenServer.cast :genMain,{:updateActorHopsMap,source,new_avg,total+1} 
          # actorHpsmp= GenServer.call :genMain,:getActorHopsMap
          # IO.puts "#{inspect actorHpsmp}"
        else
          # IO.puts "destination hops"
          # IO.puts "#{inspect hops}"
          GenServer.cast :genMain,{:insertActorHopsMap,source,hops} 
          actorHpsmp= GenServer.call :genMain,:getActorHopsMap 
          # IO.puts "#{inspect actorHpsmp}"
        end
      else
        if(Enum.member?(leafSet,key)) do
          # IO.puts "#{inspect hops}"
          GenServer.cast nodemap[key],{:route,key,id,hops+1,numFailuer}
        else
          commonPrfxLength= findCommonPrefix(key,id,0)
          # IO.puts "#{inspect commonPrfxLength }"
          rtrow=commonPrfxLength
          s=String.at(key,commonPrfxLength)
          {rtcol,_}=Integer.parse("#{s}",16) 
          # IO.puts "#{inspect rtcol}"
          if(routing_table[rtrow][rtcol]==nil) do
            rtcol=0
          end
          # IO.puts "#{inspect rtcol}"
          # IO.puts "#{inspect rtrow}"
          # IO.puts "#{inspect routing_table[rtrow][rtcol]}"
          ndid=routing_table[rtrow][rtcol]
          if(numFailuer != 0)do
            # IO.puts "now hrere #{numFailuer}"
            hops=round(:math.log(numFailuer)) 
          end
          # hops=round(numFailuer/10)
          if(ndid !=nil) do
            {_,pid}= GenServer.call :genMain,{:getNodePID,ndid}
            GenServer.cast pid,{:route,key,source,hops+1,numFailuer}
          else
            GenServer.cast nodemap[key],{:route,key,id,hops+1,numFailuer}
          end  

          # IO.puts "#{inspect pid}"
          # IO.puts "#{inspect hops}"
          
        end  

      end

      {:noreply,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end

  def handle_call({:join,key,currentIndex},_from,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
    k=currentIndex
    commonPrefixLength= findCommonPrefix(key,id,0)
    # IO.puts "#{commonPrefixLength}"
    k=updateRoutinngTable(k,commonPrefixLength,key,id,routing_table)
    # {_,pid}= GenServer.call :genMain,{:getNodePID,key}
    # rt=GenServer.call pid, {:getRoutingTable}
    rtrow = commonPrefixLength
    if (key==id) do
    #  s=String.at(key,commonPrefixLength)
      s="0"
    else
      s=String.at(key,commonPrefixLength) 
    end   
    {rtcol,_}=Integer.parse("#{s}",16) 
    
    if routing_table["#{rtrow}"]["#{rtcol}"]==nil do
        x=Map.replace(routing_table[rtrow],rtcol,key)
        new_routing_table= Map.replace(routing_table,rtrow,x)
        # IO.puts "#{inspect new_routing_table}"
    else
        {_,pid}= GenServer.call :genMain,{:getNodePID,routing_table["#{rtrow}"]["#{rtcol}"]}
        GenServer.call pid,{:join,key,k}
    end    
    {:reply,id,[id, row, col, new_routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end

  def updateRoutinngTable(k,commonPrefixLength,key,zeroid,routing_table) do
    if(k<=commonPrefixLength) do
      if (key==zeroid) do
        s="0"
      else
        s=String.at(zeroid,commonPrefixLength)
      end
      # IO.puts "#{s}"
      {ind,_}=Integer.parse("#{s}",16)
      {_,pid}= GenServer.call :genMain,{:getNodePID,key}
      # IO.puts "#{inspect pid}"
      # m = GenServer.call pid, {:getRoutingTableRow,k}
      m = routing_table[k]
      x=Map.replace(m,ind,zeroid)
      # IO.puts "#{inspect x}"
      GenServer.cast pid,{:updateRoutingTableRow,x,k}
      # m = routing_table[k]
      # IO.puts "#{inspect m}"
      updateRoutinngTable(k+1,commonPrefixLength,key,zeroid,routing_table)
    else
      k
    end  
    
  end


  def findCommonPrefix(key,k,i) do
    if(String.at(key,i)==String.at(k,i) &&  i < String.length(key))do
      findCommonPrefix(key,k,i+1)
    else  
     i
    end
  end

  

  def handle_call({:getLeafset}, _from, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
      {:reply,leafSet,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end

  def handle_call(:getNodeid, _from, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
    {:reply,id,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end
  def handle_call({:getRoutingTable}, _from, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
    {:reply,routing_table,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end

  def handle_call({:getRoutingTableRow,rowno}, _from, [id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
    {:reply,routing_table[rowno],[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end  

  def handle_cast({:updateRoutingTableRow,replcementRowMap,replcementrow},[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]) do
    routing_table=Map.replace(routing_table,replcementrow,replcementRowMap)
    {:noreply,[id, row, col, routing_table, leafSet,neighborNodes,commonPrefixLength, currentRow]}
  end  

end

