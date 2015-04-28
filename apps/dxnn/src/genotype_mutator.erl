-module(genotype_mutator).
-include("records.hrl").
-compile(export_all).

%% doc based on the node types it dispatches to the correct link function.
create_link_between_elements(AgentId, FromElement, ToElement) ->
	case {FromElement, ToElement} of
		{{_FromId, neuron}, {_ToId, neuron}} ->
			create_link_between_neurons(AgentId, FromElement, ToElement);
		{{_FromId, sensor}, {_ToId, neuron}} ->
			create_link_between_sensor_and_neuron(AgentId, FromElement, ToElement);
		{{_FromId, neuron}, {_ToId, actuator}} ->
			not_implemented
	end.

create_link_between_neurons(AgentId, FromId, ToId) ->
	Agent = genotype:read({agent, AgentId}),
	Generation = Agent#agent.generation,
	FromNeuron = genotype:read({neuron, FromId}),
 	UpdatedFromNeuron = link_from_neuron(FromNeuron, ToId, Generation),
	genotype:write(UpdatedFromNeuron),
	ToNeuron = genotype:read({neuron, ToId}),
	UpdatedToNeuron = link_to_neuron(FromId, ToNeuron, 1, Generation),
	genotype:write(UpdatedToNeuron).

create_link_between_sensor_and_neuron(AgentId, SensorId, NeuronId) ->
	Agent = genotype:read({agent, AgentId}),
	Generation = Agent#agent.generation,
	Sensor = genotype:read({sensor, SensorId}),
	UpdatedSensor = link_from_sensor(Sensor, NeuronId),
	genotype:write(UpdatedSensor),
	Neuron = genotype:read({neuron, NeuronId}),
	UpdatedNeuron = link_to_neuron(SensorId, Neuron, Sensor#sensor.vl, Generation),
	genotype:write(UpdatedNeuron).

link_from_sensor(Sensor, NeuronId) ->
	FanoutIds = Sensor#sensor.fanout_ids,
	case lists:member(NeuronId, FanoutIds) of
		true ->
			exit("******** ERROR: link_from_sensor cannot add ~p to fanout of ~p as it is already connected",
				[NeuronId, Sensor#sensor.id]);
		false ->
			Sensor#sensor{fanout_ids = [NeuronId|FanoutIds]}
	end.

link_from_neuron(FromNeuron, ToId, Generation) ->
	{{FromLayerIndex, _}, _} = FromNeuron#neuron.id,
	{{ToLayerIndex, _}, _} = ToId,
	OutputIds = FromNeuron#neuron.output_ids,
	RecursiveOutputIds = FromNeuron#neuron.recursive_output_ids,
	case lists:member(ToId, OutputIds) of
		true ->
			exit("******** ERROR: link_from_neuron cannot add ~p to output of ~p as it is already connected",
				[ToId, FromNeuron#neuron.id]);
		false ->
			{UpdatedOutputIds, UpdatedRecursiveOutputIds} = case ToLayerIndex >= FromLayerIndex of
				true ->
					{[ToId|OutputIds], [ToId|RecursiveOutputIds]};
				false ->
					{[ToId|OutputIds], RecursiveOutputIds}
			end,
			FromNeuron#neuron{
				output_ids = UpdatedOutputIds,
				recursive_output_ids = UpdatedRecursiveOutputIds,
				generation = Generation
			}
	end.

link_to_neuron(FromNeuronId, ToNeuron, VectorLength, Generation) ->
	InputIdsPlusWeights = ToNeuron#neuron.input_ids_plus_weights,
	case lists:keymember(FromNeuronId, 1, InputIdsPlusWeights) of
		true ->
			exit("******** ERROR: link_to_neuron cannot add ~p to input of ~p as it is already connected",
				[FromNeuronId, ToNeuron#neuron.id]);
		false ->
			UpdatedInputIdsPlusWeights = 
				[{FromNeuronId, genotype:create_neural_weights(VectorLength)}|InputIdsPlusWeights],
			ToNeuron#neuron{
				input_ids_plus_weights = UpdatedInputIdsPlusWeights,
				generation = Generation
			}
	end.

cut_link_between_elements() ->
	not_implemented.


