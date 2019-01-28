# Exmachina

A non-traditional approach to modelling a neural network.

Here I use elixir to model each neuron as a seperate asynchrounous process. Neuron receive signals, compute an output, receive an error signal and updates weights, all as a completely self contained process. As opposed to the more traditional approach of updating an entire layer at once as a matrix operation.

This is much slower than matrix operations performed on a GPU, but its also (I hope) much easier to understand.

## How to use

Just use the mix task:

```
mix learn
```

## How does it work?

### The steps a Neuron goes through

1) Wait for all input neurons to send it activities (remember these connections)
1) Compute its own activity based on received activities
1) "weight" the activity for each outgoing connection (using a different weight per output connection)
1) Send the weighted activities to outputs
1) Wait for all output responses. (IE the "error" of each connected output neuron)
1) Compute the neurons own "error" based on the error of each of the received outputs, the corresponding weight, and the last activity that was sent
1) Send the "error" back to open connections from step 1
1) Compute the error amount for each of the outgoing weights
1) Update weights

https://www.youtube.com/watch?v=Z8jzCvb62e8&list=PLoRl3Ht4JOcdU872GhiYWf6jwrk_SNhz9&index=13

### Dodgy diagram of a neuron

```
         /
      \ |
       \|/
  /|\   |      < axon
   |   \| /
   |    |/
   |    |     }
        |     > (neuron)
        |     }
        0
      / | \
    /|\/|\/|\  < dendrites

```

A neuron receives activity from other neurons connected at it dendrites and sends that activity to more neurons connected along its axon. As such, activities travel UP the neuron.

The activity the neuron sends along its axon is different at each synapse (aka connection) on the axon.
The activities are calculated in the following way:

- Sum up all the incoming activity at the dendrites
- Plot the sum against a sigmoid logistic function to get a 0-1 float (https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Logistic-curve.svg/1200px-Logistic-curve.svg.png)
- This 0-1 logistic-sum is the neurons "activity"
- Send the "activity" up the axon to all the synapses
- At each synapse, modify the activity (ie increase it or reduce it) based on the "weight" or strength of each connection. So that the connected neurons receive a "weighted-activity" on their respective dendrites

The weights or connection strengths at the synapses on the axon start off random and then are "learned".
Learning happens similarly to actioning, but in reverse:

- Receive "Errors" from the connected neurons on the axons (an "error" is a number that represents how well the previous action contributed to the accuracy of the overall network output - ie did the activity contribute to a right answer or a wrong answer)
- Also at each synapse, change the connection strength (aka weight) by the error on that connection modified by the previous "activity" of the neuron. That is to say, if the neuron sent a large activity and we got a big error, then modify the weight a lot. If the neuron sent a small activity and got a big error then modify it a small amount.

Then, we continue to send the error backwards through the network:

- Modify the errors we received at each axon synapse using the strength of the connection to get a weighted-error at each synapse
- Sum up the weighted-errors
- Modify the summed-weighted-errors by the previous neuron "activity". That is to say, if the neuron sent a large activity and we got big errors, then make the error even bigger. If the neuron sent a small activity and got big errors then make the error a bit smaller.
- Send this modified-summed-weighted-error down the dentrites to the connected neurons
