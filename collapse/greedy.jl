#################################################################
#                   Includes and Modules                        #
#################################################################

using LinearAlgebra, Arpack, Random, SparseArrays
using BenchmarkTools, Printf, TimerOutputs
Random.seed!(12345)

#include("../m1Accel.jl")

include("../HOLaGraf_lsmr.jl")
using .HOLaGraf_lsmr
include("../generateDelauney.jl")

# Plotting thingies 
using Plots, ColorSchemes, Plots.PlotMeasures,  LaTeXStrings
pgfplotsx()
theme(:mute)
Plots.scalefontsizes(1.25)
cols=ColorSchemes.Spectral_11;

# Sampling
using StatsBase
using GR: delaunay

#################################################################
#                End of Includes and Modules                    #
#################################################################


#################################################################
#                   Functions of Sets                          #
#################################################################

"""
    getEdges2Trig( edges2, trigs2 )

Create a vector of sets of triangles adjacent to edges
"""
function getEdges2Trig( edges2, trigs2 )
      edg2Trig = [];
      for i in axes(edges2, 1)
            tmp = [];
            for j in axes(trigs2, 1)
                  if ((trigs2[j, 1] == edges2[i, 1]) && (trigs2[j, 2] == edges2[i, 2])) || ((trigs2[j, 1] == edges2[i, 1]) && (trigs2[j, 3] == edges2[i, 2])) || ((trigs2[j, 2] == edges2[i, 1]) && (trigs2[j, 3] == edges2[i, 2]))
                        tmp=[tmp; j];
                  end
            end
            edg2Trig = [edg2Trig; Set(tmp)];
      end
      return edg2Trig
end
      
"""
    getTrig2Edg( edges2, trigs2, edg2Trig )

create a vector of sets of edges adjacent to triangles
"""
function getTrig2Edg( edges2, trigs2, edg2Trig )
      trig2Edg = [ Set{Int64}([]) for i in axes(trigs2, 1) ];
      for i in axes(edges2, 1)
            for j in edg2Trig[i]
                  push!(trig2Edg[j], i)
            end
      end
      return trig2Edg
end
      
#################################################################
#             END of Functions of Sets                          #
#################################################################



#################################################################
#                Functions of Delaunay                          #
#################################################################

function sparseDelaunay( ; N = 10, ?? = 0.4 )
      n  = N + 4;

      points, edges, trigs = generateDelauney( N )
      ??_init = size(edges, 1 ) / ( ( N + 4) * ( N + 3 ) / 2 );

      backlash = Int( - size( edges, 1 ) + round( ?? * n * (n-1) / 2 ) ) 

      if backlash < 0
            for i in 1 : -backlash
                  ind = getIndx2Kill( edges ) ;
                  edges, trigs = killEdge(ind, n, edges, trigs)
            end
      else
            allEdges = Array{Integer}(undef, 0, 2)
            for i in 1:(n-1) 
                  for j in (i+1):n
                        allEdges = [ allEdges; i j  ]
                  end
            end
            for i in 1:size(edges, 1)
                  indx = findall(all(allEdges .== edges[i, :]', dims=2))[1][1]
                  allEdges = allEdges[ 1:size(allEdges, 1) .!= indx, : ]
            end
            for i in 1 : backlash      
                  ind, allEdges = getNewEdge2(n, edges, allEdges);
                  edges, trigs = addEdge(ind, n, edges, trigs)
            end
      end

      return n, points, ??_init, edges, trigs

end

#################################################################
#            END of Functions of Delaunay                       #
#################################################################


function greedyCollapse( edges, trigs )
      edge2Trig = getEdges2Trig(edges, trigs)
      trig2Edg = getTrig2Edg(edges, trigs, edge2Trig)

      Ls = [ length(edge2Trig[i]) for i in 1 : size( edges, 1 ) ]
      Free = Set([ i for i in 1 : size(edges, 1 ) if Ls[i] == 1 ])

      ?? = [];

      while !isempty(Free)
            ?? = pop!(Free) 
            ?? = [ ??; ?? ]
            ?? = first( edge2Trig[ ?? ] ) 
            for ?? in trig2Edg[ ?? ]
                  setdiff!( edge2Trig[ ?? ], Set([ ?? ]) )
                  Ls[ ?? ] = Ls[ ?? ] - 1
                  ( Ls[ ?? ] == 1 ) && ( union!(Free, Set( [ ?? ] ) ) )
                  ( Ls[ ?? ] == 0 ) && ( setdiff!(Free, Set( [ ?? ] ) ) )
            end
      end
      return sum( Ls ) == 0, ??, edge2Trig, trig2Edg, Ls, Free  
end





Random.seed!(0)

n, points, ??_init, edges, trigs = sparseDelaunay( N = 10, ?? = 0.4)
flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )




N = 20
??_init = ( 3*(N+4) - 7 ) / ( (N+4)*(N+3)/2 )
??s = Array( ??_init*1.005:0.001: ??_init*1.25 )
rep = 500
freq = zeros( size(??s, 1), 1 )

for i in 1:size(??s, 1)
      global ??s, rep, N, freq
      ?? = ??s[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, ??_init, edges, trigs = sparseDelaunay( N = N, ?? = ??)
            flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
            !flag && ( freq[i] = freq[i] + 1 )
      end

end

freq = freq / rep



N = 10
??_init01 = ( 3*(N+4) - 7 ) / ( (N+4)*(N+3)/2 )
??s01 = Array( ??_init01*1.005:0.001: ??_init01*1.25 )
rep = 500
freq01 = zeros( size(??s01, 1), 1 )

for i in 1:size(??s01, 1)
      global ??s01, rep, N, freq01
      ?? = ??s01[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, ??_init01, edges, trigs = sparseDelaunay( N = N, ?? = ??)
            flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
            !flag && ( freq01[i] = freq01[i] + 1 )
      end

end

freq01 = freq01 / rep

N = 15
??_init015 = ( 3*(N+4) - 7 ) / ( (N+4)*(N+3)/2 )
??s015 = Array( ??_init015*1.005:0.001: ??_init015*1.25 )
rep = 500
freq015 = zeros( size(??s015, 1), 1 )

for i in 1:size(??s015, 1)
      global ??s015, rep, N, freq015
      ?? = ??s015[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, ??_init015, edges, trigs = sparseDelaunay( N = N, ?? = ??)
            flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
            !flag && ( freq015[i] = freq015[i] + 1 )
      end

end

freq015 = freq015 / rep

plot()

plot!( ??s[vec(freq.>0)]/??_init, freq[vec(freq.>0)], marker = :circle, xscale=:log10, yscale=:log10, label=L"\mathcal{V}_0(\mathcal K)=24")
#plot!( [??_init, ??_init], [0, 1], color=:black )

plot!( ??s01[vec(freq01.>0)]/??_init01, freq01[vec(freq01.>0)], marker = :circle, xscale=:log10, label=L"\mathcal{V}_0(\mathcal K)=14" )
#plot!( [??_init01, ??_init01], [0, 1], color=:black )

plot!( ??s015[vec(freq015.>0)]/??_init015, freq015[vec(freq015.>0)], marker = :circle, xscale=:log10, label=L"\mathcal{V}_0(\mathcal K)=19")
#plot!( [??_init015, ??_init015], [0, 1], color=:black )

plot!([1, 1], [0.25, 1], color=:black, linestyle=:dash, label="")
xticks!( [1, 1.1, 1.25], [L"\nu_\Delta", L"1.1\nu_\Delta", L"1.25\nu_\Delta"], tickfontsize=18 )
yticks!( [ 0.25, 0.5, 1], [L"0.25", L"0.5", L"1"])
xlabel!(L"\mathrm{sparsity \; (wrt \; triangulation)}", xguidefontsize = 22)
ylabel!(L"\mathrm{probability \; of \; 2-Core}", yguidefontsize = 22)
plot!( size=( 600, 600 ), legend=:bottomright, legendfont=font(22) )

savefig("triang_prob.tex")
savefig("triang_prob.pdf")





#                                                                      #

dist( x, y ) = norm( x - y, 2 )

function generateSensor( N = 10 , eps = 0.5)
      points =  rand(N, 2)
      edges = Array{Integer}(undef, 0, 2)
      for i in 1 : N-1
            for j in i+1 : N
                  if dist( points[i, :], points[j, :] ) < eps
                        edges = [edges; i j ]
                  end
            end
      end
      edges

      trigs = Array{Integer}(undef, 0, 3)

      for i in 1 : size( edges, 1 )-1
            for j in i+1 : size( edges, 1 )
                  if edges[ i, 1 ] == edges[ j, 1 ]
                        if sum( all( edges .== sort([ edges[i, 2] edges[j, 2] ]; dims=2)  , dims = 2) ) > 0
                              trigs = [ trigs; sort( [ edges[i, 1] edges[i, 2] edges[j, 2] ]; dims = 2 ) ]
                        end
                  end
            end
      end
      return N, points, edges, trigs
end

using Distances
function minimumSensorDistance( N = 10)
      rep = 1000
      res = 0 
      for i in 1:rep
            points = rand( N, 2 )
            Mat = pairwise(euclidean, points, dims=1)
            Mat[diagind(Mat)] .= 1 
            res = res + minimum(Mat)
      end
      return res/rep
end


N = 20
eps = 0.5

Random.seed!(1)
n, points, edges, trigs = generateSensor(N, eps)
flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )





N = 20
min_?? = minimumSensorDistance(N)
??s = Array(min_??:0.01:0.45)
rep = 500
freq = zeros( size(??s, 1), 1 )
nus = zeros( size(??s, 1), 1 )

for i in 1:size(??s, 1)
      global ??s, rep, N, freq
      eps = ??s[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, edges, trigs = generateSensor(N, eps)
            nus[i] = nus[i] + size(edges, 1) / ( n * (n-1) / 2 )
            if size(edges, 1) > 0
                  flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
                  !flag && ( freq[i] = freq[i] + 1 )
            end
      end

end

nus = nus / rep
freq = freq / rep


N = 10
min_??01 = minimumSensorDistance(N)
??s01 = Array(min_??01:0.01:0.45)
rep = 500
freq01 = zeros( size(??s01, 1), 1 )
nus01 = zeros( size(??s01, 1), 1 )


for i in 1:size(??s01, 1)
      global ??s01, rep, N, freq01
      eps = ??s01[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, edges, trigs = generateSensor(N, eps)
            nus01[i] = nus01[i] + size(edges, 1) / ( n * (n-1) / 2 )
            if size(edges, 1) > 0
                  flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
                  !flag && ( freq01[i] = freq01[i] + 1 )
            end
      end

end

nus01 = nus01 / rep
freq01 = freq01 / rep



N = 15
min_??015 = minimumSensorDistance(N)
??s015 = Array(min_??015:0.01:0.45)
rep = 500
freq015 = zeros( size(??s015, 1), 1 )
nus015 = zeros( size(??s015, 1), 1 )


for i in 1:size(??s015, 1)
      global ??s015, rep, N, freq015
      eps = ??s015[i]
      for j in 1:rep
            Random.seed!(j)
            n, points, edges, trigs = generateSensor(N, eps)
            nus015[i] = nus015[i] + size(edges, 1) / ( n * (n-1) / 2 )
            if size(edges, 1) > 0
                  flag, ??, edge2Trig, trig2Edg, Ls, Free = greedyCollapse( edges, trigs )
                  !flag && ( freq015[i] = freq015[i] + 1 )
            end
      end
end

nus015 = nus015 / rep 
freq015 = freq015 / rep




plot()
plot!( ??s[vec(freq .> 0)]/min_??, freq[vec(freq .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 20", xscale = :log10, yscale = :log10 )
plot!( ??s01[vec(freq01 .> 0)]/min_??01, freq01[vec(freq01 .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 10" )
plot!( ??s015[vec(freq015 .> 0)]/min_??015, freq015[vec(freq015 .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 15" )
xlabel!(L"\mathrm{percolation, \;} \varepsilon", xguidefontsize = 22)
ylabel!(L"\mathrm{probability \; of \; 2-Core}", yguidefontsize = 22)
plot!(size=(600, 600), legend = :bottomright, legendfont = font(22), tickfontsize=18 )
xticks!([1.2, 3, 10], [L"\varepsilon_{\min}", L"3\varepsilon_{\min}", L"10\varepsilon_{\min}"])


savefig("percol_prob.tex")
savefig("percol_prob.pdf")





plot()
plot!( nus[vec(freq .> 0)]/nus[1], freq[vec(freq .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 20", xscale = :log10, yscale = :log10 )
plot!( nus01[vec(freq01 .> 0)]/nus01[1], freq01[vec(freq01 .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 10" )
plot!( nus015[vec(freq015 .> 0)]/nus015[1], freq015[vec(freq015 .> 0)], marker = :circle, label = L"\mathcal{V}_0(\mathcal K) = 15" )
xlabel!(L"\mathrm{sparsity \; (wrt \; } \varepsilon_{\min})", xguidefontsize = 22)
ylabel!(L"\mathrm{probability \; of \; 2-Core}", yguidefontsize = 22)
plot!(size=(600, 600), legend = :bottomright, legendfont = font(22), tickfontsize=18 )
#xticks!([1.2, 3, 10], [L"\varepsilon_{\min}", L"3\varepsilon_{\min}", L"10\varepsilon_{\min}"])















N = 20

eps = 0.2

edges = Array{Integer}(undef, 0, 2)
for i in 1 : N-1
      for j in i+1 : N
            if dist( points[i, :], points[j, :] ) < eps
                  edges = [edges; i j ]
            end
      end
end
edges

trigs = Array{Integer}(undef, 0, 3)

for i in 1 : size( edges, 1 )-1
      for j in i+1 : size( edges, 1 )
            if edges[ i, 1 ] == edges[ j, 1 ]
                  if sum( all( edges .== sort([ edges[i, 2] edges[j, 2] ]; dims=2)  , dims = 2) ) > 0
                        trigs = [ trigs; sort( [ edges[i, 1] edges[i, 2] edges[j, 2] ]; dims = 2 ) ]
                  end
            end
      end
end













