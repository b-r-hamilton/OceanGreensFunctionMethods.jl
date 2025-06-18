# follows the design of Tom Haine's pedagaogical box model

# define units
kg = u"kg"
m  = u"m"
yr = u"yr"
Tg = u"Tg"
s  = u"s"
pmol = u"pmol"
fmol = u"fmol"
nmol = u"nmol"

# define dimensional labels
@dim Tracer "tracer"
@dim Meridional "meridional location"
@dim Vertical "vertical location"
@dim Global "global quantity"

# define a structure for 2D fluxes in a yz domain
struct Fluxes{T,A<:AbstractArray{T}} 
    north::A
    south::A
    up::A
    down::A
end

+(F1::Fluxes, F2::Fluxes) = Fluxes(
    F1.north + F2.north,
    F1.south + F2.south,
    F1.up + F2.up,
    F1.down + F2.down)

dims(F::Fluxes) = dims(F.north)

meridional_names() = ["High latitudes", "Mid-latitudes", "Low latitudes"]
vertical_names() = ["Thermocline", "Deep", "Abyssal"]

"""
    model_dimensions()

Define labels for the model's physical dimensions, as well as labels for the box names. Use the format of `DimensionalData.jl`. Permits numerical quantities to be bundled with their meta-data. Dimensions are `Unordered` to avoid issues related to the alphabetical order.
"""
model_dimensions() = (Meridional(meridional_names(); order=DimensionalData.Unordered()),
    Vertical(vertical_names(); order=DimensionalData.Unordered())) 

"""
    boundary_dimensions()

Define labels for the boundary's physical dimensions, as well as labels for the box names, consistently with the model dimensions. Use the format of `DimensionalData.jl`. Permits numerical quantities to be bundled with their meta-data. Dimensions are `Unordered` to avoid issues related to the alphabetical order.
"""
boundary_dimensions() = (Meridional(meridional_names()[1:2]; order=DimensionalData.Unordered()),
    Vertical([vertical_names()[1]]; order=DimensionalData.Unordered())) 

# function Base.zeros(model_dims, type::Symbol)
#     if type == :Fluxes
#         Fv_zeros = zeros(model_dims, :VectorArray)*Fv_units
#         return Fluxes(Fv_zeros, Fv_zeros, Fv_zeros, Fv_zeros)
#     else
#         error("zeros not implemented for this type")
#     end
# end
    
"""
    abyssal_overturning(Ψ,model_dims)

Set volume flux, Ψ, in an abyssal overturning loop that satisfies the conservation of volume. Return a structure of `Fluxes`.
"""
function abyssal_overturning(Ψ,model_dims)

    # pre-allocate volume fluxes with zeros with the right units
    Fv_units = unit(Ψ)
    Fv_north = zeros(model_dims, :VectorArray)*Fv_units
    Fv_south = zeros(model_dims, :VectorArray)*Fv_units
    Fv_up = zeros(model_dims, :VectorArray)*Fv_units
    Fv_down = zeros(model_dims, :VectorArray)*Fv_units

    # set fluxes manually
    # fluxes organized according to (upwind) source of flux
    Fv_north[At("Low latitudes"),At("Thermocline")] = Ψ 
    Fv_north[At("Mid-latitudes"),At("Thermocline")] = Ψ 

    Fv_south[At("Mid-latitudes"),At("Abyssal")] = Ψ 
    Fv_south[At("High latitudes"),At("Abyssal")] = Ψ 

    Fv_up[At("Low latitudes"),At("Abyssal")] = Ψ 
    Fv_up[At("Low latitudes"),At("Deep")] = Ψ 

    Fv_down[At("High latitudes"),At("Thermocline")] = Ψ 
    Fv_down[At("High latitudes"),At("Deep")] = Ψ 

    return Fluxes(Fv_north, Fv_south, Fv_up, Fv_down)
end

"""
    intermediate_overturning(Ψ,model_dims)

Set the volume flux, Ψ, in an intermediate overturning loop that satisfies the conservation of volume. Return a structure of `Fluxes`.
"""
function intermediate_overturning(Ψ,model_dims)

    # pre-allocate volume fluxes with zeros with the right units
    Fv_units = unit(Ψ)
    Fv_north = zeros(model_dims, :VectorArray)*Fv_units
    Fv_south = zeros(model_dims, :VectorArray)*Fv_units
    Fv_up = zeros(model_dims, :VectorArray)*Fv_units
    Fv_down = zeros(model_dims, :VectorArray)*Fv_units

    # set fluxes manually
    # fluxes organized according to (upwind) source of flux
    Fv_north[At("Mid-latitudes"),At("Abyssal")] = Ψ 
    Fv_north[At("Low latitudes"),At("Abyssal")] = Ψ 

    Fv_south[At("High latitudes"),At("Deep")] = Ψ 
    Fv_south[At("Mid-latitudes"),At("Deep")] = Ψ 

    Fv_up[At("High latitudes"),At("Abyssal")] = Ψ 
    Fv_down[At("Low latitudes"),At("Deep")] = Ψ 

    return Fluxes(Fv_north, Fv_south, Fv_up, Fv_down)
end


"""
    vertical_diffusion(Fv_exchange,model_dims)

Set vertical diffusive-like exchange flux `Fv_exchange`. Return a structure of `Fluxes`.
"""
function vertical_diffusion(Fv_exchange,model_dims)

    # pre-allocate volume fluxes with zeros with the right units
    Fv_units = unit(Fv_exchange)
    Fv_north = zeros(model_dims, :VectorArray)*Fv_units
    Fv_south = zeros(model_dims, :VectorArray)*Fv_units
    Fv_up = zeros(model_dims, :VectorArray)*Fv_units
    Fv_down = zeros(model_dims, :VectorArray)*Fv_units

    # set fluxes manually
    # fluxes organized according to (upwind) source of flux
    # missing proper broadcast for VectorDimArray: add `parent` below
    #parent(Fv_up)[:,At(["Abyssal","Deep"])] .= Fv_exchange 
    #parent(Fv_down)[:,At(["Thermocline","Deep"])] .= Fv_exchange 
    Fv_up[:,At(["Abyssal","Deep"])] =
             Fv_up[:,At(["Abyssal","Deep"])] .+ Fv_exchange 
    Fv_down[:,At(["Thermocline","Deep"])] =
        Fv_down[:,At(["Thermocline","Deep"])] .+ Fv_exchange 
    
    return Fluxes(Fv_north, Fv_south, Fv_up, Fv_down)
end

"""
    advective_diffusive_flux(C, Fv; ρ)

Advective-diffusive flux of tracer `C` given volume fluxes `Fv` and optional density `ρ`.

# Arguments
- `C::VectorDimArray`: tracer distribution
- `Fv::VectorDimArray`: volume fluxes
- `ρ::Number=1035kg/m^3`: uniform density
# Returns
- `Fc::VectorDimArray`: tracer flux
"""
advective_diffusive_flux(C::VectorDimArray, Fv::VectorDimArray ; ρ = 1035kg/m^3) = ρ * (Fv .* C) .|> Tg/s

"""
    advective_diffusive_flux(C, Fv; ρ)

Advective-diffusive flux of tracer `C` given volume fluxes `Fv` and optional density `ρ`.

# Arguments
- `C::VectorDimArray`: tracer distribution
- `Fv::Fluxes`: volume fluxes
- `ρ::Number=1035kg/m^3`: uniform density
# Returns
- `Fc::Fluxes`: tracer flux
"""
advective_diffusive_flux(C::VectorDimArray, Fv::Fluxes ; ρ = 1035kg/m^3) =
    Fluxes(
        advective_diffusive_flux(C, Fv.north, ρ=ρ),
        advective_diffusive_flux(C, Fv.south, ρ=ρ),
        advective_diffusive_flux(C, Fv.up, ρ=ρ),
        advective_diffusive_flux(C, Fv.down, ρ=ρ)
    )

"""    
    mass(V; ρ)

Seawater mass derived from the volume `V` and an optional input of density `ρ`.
"""
mass(V; ρ = 1035kg/m^3) = ρ * V .|> u"Zg"

"""
    convergence(J)

Convergence of fluxes `J` of type `Fluxes`.
This is a computational method that depends on proper slices and broadcasting
and thus currently requires using `parent` on the left hand side below.
"""
function convergence(J::Fluxes{T,A}) where {T, A <: VectorDimArray{T}}

    # all the fluxes leaving a box
    deldotJ = -( J.north + J.south + J.up + J.down)

    # add `parent` to handle proper broadcasting
    
    # #north flux entering
    # parent(deldotJ)[At(["Mid-latitudes","High latitudes"]),:] .+=
    #    J.north[At(["Low latitudes","Mid-latitudes"]),:]

    # #south flux entering
    # parent(deldotJ)[At(["Low latitudes","Mid-latitudes"]),:] .+=
    #     J.south[At(["Mid-latitudes","High latitudes"]),:]

    # # upward flux entering
    # parent(deldotJ)[:,At(["Thermocline","Deep"])] .+=
    #     J.up[:,At(["Deep","Abyssal"])]

    # # downward flux entering
    # parent(deldotJ)[:,At(["Deep","Abyssal"])] .+=
    #     J.down[:,At(["Thermocline","Deep"])]
#=
    #alternatively, could write
    deldotJ[At(["Mid-latitudes","High latitudes"]),:] =
       deldotJ[At(["Mid-latitudes","High latitudes"]),:] .+
       J.north[At(["Low latitudes","Mid-latitudes"]),:]

    deldotJ[At(["Low latitudes","Mid-latitudes"]),:] =
        deldotJ[At(["Low latitudes","Mid-latitudes"]),:] .+
        J.south[At(["Mid-latitudes","High latitudes"]),:]

    # upward flux entering
    deldotJ[:,At(["Thermocline","Deep"])] =
        deldotJ[:,At(["Thermocline","Deep"])] .+
        J.up[:,At(["Deep","Abyssal"])]

    # downward flux entering
    deldotJ[:,At(["Deep","Abyssal"])] =
        deldotJ[:,At(["Deep","Abyssal"])] .+
        J.down[:,At(["Thermocline","Deep"])]
       =#
    # this fails, but is a goal to make this work
    #deldotJ[At(["Mid-latitudes","High latitudes"]),:] .+=
    #    J.north[At(["Low latitudes","Mid-latitudes"]),:]
    sx = size(deldotJ)[1]
    sy = size(deldotJ)[2]
    deldotJ[:, 1:sy-1] .+= J.up[:, 2:sy]
    deldotJ[:, 2:sy] .+= J.down[:, 1:sy-1]
    deldotJ[1:sx-1, :] .+= J.north[2:sx, :]
    deldotJ[2:sx, :] .+= J.south[1:sx-1, :]
    return deldotJ
end

"""
    mass_convergence(Fv) 

Convergence of volume derived from a field of volume fluxes `Fv`, translated into a mass flux convergence with the assumption of uniform density.  
"""
mass_convergence(Fv) = convergence(advective_diffusive_flux( ones(dims(Fv), :VectorArray), Fv))

function local_boundary_flux(f::VectorDimArray,
    C::VectorDimArray,
    Fb::VectorDimArray)
    
    ΔC = f - C[DimSelectors(f)] # relevant interior tracer difference from boundary value
    return advective_diffusive_flux(ΔC, Fb)
end

"""
    boundary_flux(f::VectorDimArray, C::VectorDimArray, Fb::VectorDimArray)

Convergence or net effect of boundary fluxes.

# Arguments
- `f::VectorDimArray`: Dirichlet boundary condition
- `C::VectorDimArray`: tracer distribution 
- `Fb::VectorDimArray`: boundary exchange volume flux
# Returns
- `Jb::Fluxes`: boundary tracer flux
"""
function boundary_flux(f::VectorDimArray, C::VectorDimArray, Fb::VectorDimArray)
    Jlocal = local_boundary_flux(f, C, Fb)
    Jb = unit(first(Jlocal)) * VectorArray(zeros(dims(C))) # pre-allocate
    Jb[DimSelectors(f)] += Jlocal # transfer J at boundary locations onto global grid
    return Jb
end

"""
    radioactive_decay(C, halflife)

Radioactive decay rate of tracer `C` with half life of `halflife`.
"""
radioactive_decay(C::VectorArray, halflife::Number) = -(log(2)/halflife)*C 

"""
    tracer_tendency(C, f, Fv, Fb, V)

Tracer tendency ∂C/∂t for a tracer `C`, especially useful for finding a tracer transport matrix. 

# Arguments
- `C::VectorDimArray`: tracer distribution
- `f::VectorDimArray`: Dirichlet boundary condition
- `Fv::Fluxes`: volume fluxes
- `Fb::VectorDimArray`: boundary flux convergence
- `V::VectorDimArray`: box volume
# Returns
- `dCdt::VectorDimArray`: tracer tendency
"""
tracer_tendency(
    C::VectorDimArray,
    f::VectorDimArray,
    Fv::Fluxes{T,<:VectorDimArray},
    Fb::VectorDimArray,
    V::VectorDimArray) where T =
    ((convergence(advective_diffusive_flux(C, Fv)) +
                  boundary_flux(f, C, Fb)) ./
                  mass(V)) .|> yr^-1 

"""
    tracer_tendency(f, C, Fv, Fb, V)

Tracer tendency ∂C/∂t for a boundary flux `f`, for use with finding B boundary matrix.

# Arguments
- `f::VectorDimArray`: Dirichlet boundary condition
- `C::VectorDimArray`: tracer distribution
- `Fv::Fluxes`: volume fluxes
- `Fb::Fluxes`: volume fluxes
- `V::VectorDimArray`: box volume
# Returns
- `dCdt::VectorDimArray`: tracer tendency
"""
tracer_tendency(
    f::VectorDimArray,
    C::VectorDimArray,
    Fb::VectorDimArray,
    V::VectorDimArray) =
    (boundary_flux(f, C, Fb) ./
    mass(V)) .|> yr^-1 

# for use with finding A perturbation with radioactive decay
"""
    tracer_tendency(C)

Tracer tendency ∂C/∂t for the radioactive decay of a tracer `C` with half life `halflife`, for use with finding the radioactive contribution to a tracer transport matrix.

# Arguments
- `C::VectorDimArray`: tracer distribution
- `halflife::Number`: radioactive half life
# Returns
- `dCdt::VectorDimArray`: tracer tendency
"""
tracer_tendency(C::VectorDimArray, halflife::Number) =
    radioactive_decay(C, halflife) .|> yr^-1 

"""
    linear_probe(funk, x, args...)

Probe a function to determine its linear response in matrix form. Assumes units are needed and available. A simpler function to handle cases without units would be nice.

# Arguments
- `funk`: function to be probed
- `x`: input (independent) variable
- `halflife::Number`: radioactive half life
- `args`: the arguments that follow `x` in `funk`
# Returns
- `A::MatrixDimArray`: labeled transport information used in matrix operations 
"""
function linear_probe(funk::Function,C::VectorArray{T, N, DA}, args...) where {T, N, DA <: DimensionalData.AbstractDimArray} #where T <: Number # where N

    dCdt0 = funk(C, args...)

    # meta data for VectorArray changes
    Trow = typeof(parent(dCdt0-dCdt0))

    # would prefer to use parameterized type rather than Trow
    A = Array{Trow}(undef,size(C))
    #A = Array{Any}(undef,size(C))

    for i in eachindex(C)
        C[i] += 1.0 *unit(first(C))
        
        # remove baseline if not zero
        Δ = funk(C, args...) - dCdt0
        
        # not strictly necessary for linear system
        # error: can't convert, units issue?
        #A[i] = parent(funk(C, args...) - dCdt0)
        A[i] = parent(Δ)

        #A[i] = parent(funk(C, args...))
        C[i] -= 1.0  *unit(first(C)) # yes, necessary
    end
    return MatrixArray(DimArray(A, dims(C)))
    #return AlgebraicArray(A, dims(C))
end

allequal(x) = all(y -> y == first(x), x)

"""
    location_transient_tracer_histories()

URL of tracer source history file.
"""
location_transient_tracer_histories() = "https://github.com/ThomasHaine/Pedagogical-Tracer-Box-Model/raw/main/MATLAB/tracer_gas_histories.mat"

"""
    location_transient_tracer_histories()

URL of iodine-129 source history file.
"""
location_iodine129_history() = 
    "https://raw.githubusercontent.com/ThomasHaine/Pedagogical-Tracer-Box-Model/main/MATLAB/From%20John%20Smith/Input%20Function%20129I%20Eastern%20Norwegian%20Sea.csv"

"""
    read_iodine129_history()
"""
function read_iodine129_history()
    url = location_iodine129_history()
    !isdir(datadir()) && mkpath(datadir())
    filename = datadir("iodine129_history.nc")

    # allow offline usage if data already downloaded
    !isfile(filename) && Downloads.download(url,filename)

    # use CSV to open
    ds = CSV.File(filename)# , DataFrame)

    source_iodine = vcat(0.0,0.0,parse.(Float64,ds.Column2[4:end]))
    t_iodine = vcat(0.0,1957.0,parse.(Float64,ds.var"Atlantic Water in Eastern Norwegian Sea entering Barents Sea and West Spitzbergen Current"[4:end]))

    tracerdim = Tracer([:iodine129])
    timedim = Ti((t_iodine)yr)

    BD = zeros(tracerdim,timedim)
    BD[Tracer=At(:iodine129)] = source_iodine # note that this does NOT introduce a variable ``varname`` into scope

    return BD
end 

"""
    read_transient_tracer_histories()

Read transient tracer source histories and save as a `DimArray`. 
"""
function read_transient_tracer_histories()

    # download tracer history input (make this lazy)
    url = location_transient_tracer_histories()
    !isdir(datadir()) && mkpath(datadir())
    filename = datadir("tracer_histories.mat")

    # allow offline usage if data already downloaded
    !isfile(filename) && Downloads.download(url,datadir("tracer_histories.mat"))

    file = matopen(filename)

    # all matlab variables except Year
    varnames = Symbol.(filter(x -> x ≠ "Year", collect(keys(file))))
    tracerdim = Tracer(varnames)
    timedim = Ti(vec(read(file, "Year"))yr)

    BD = zeros(tracerdim,timedim)
    
    for v in varnames
        BD[Tracer=At(v)] = read(file, string(v)) # note that this does NOT introduce a variable ``varname`` into scope
    end
    close(file)
    return BD
end

tracer_units() = Dict(
    :CFC11NH => NoUnits,
    :CFC11SH => NoUnits,
    :CFC12NH => NoUnits,
    :CFC12SH => NoUnits,
    :argon39 => NoUnits,
    :iodine129 => NoUnits,
    :SF6NH => NoUnits,
    :SF6SH => NoUnits,
    :N2ONH => nmol/kg,
    :N2OSH => nmol/kg,
    :Bool => NoUnits, 
    :C14 => NoUnits
    )

    # for non-transient tracers
function tracer_point_source_history(tracername)

    if tracername == :argon39
        return x -> 1.0 * tracer_units()[tracername]
    elseif tracername == :iodine129
        error("not implemented yet")
    end
end

"""
    tracer_point_source_history(tracername, BD)

Return a function that yields transient tracer source history (such as CFCs) at given time.

# Arguments
- `tracername`: name of tracer in source history file
- `BD::DimArray`: Dirichlet boundary condition compendium for many tracers
"""
function tracer_point_source_history(tracername, BD)
    tracer_timeseries = BD[Tracer=At(tracername)] * tracer_units()[tracername]
    if length(dims(BD)) == 2 
        return linear_interpolation(
            first(DimensionalData.index(dims(tracer_timeseries))),
            tracer_timeseries)
    else
        dtt = dims(tracer_timeseries)
        ydim = 1:length(dtt[2]) #Meridional 
        nodes = ([x for x in dtt[1]], ydim)
        tpsh(t) = interpolate(nodes,tracer_timeseries.data,(Gridded(Linear()), NoInterp()))(t, 1:length(dtt[2]))
        return tpsh

    end
    
        
end

"""
    tracer_source_history(t, tracername, box2_box1_ratio, BD = nothing)

Return source history values for all boundary points.

# Arguments
- `t`: time
- `tracername`: name of tracer in source history file
- `box2_box1_ratio`: ratio of boundary condition value in Mid-latitudes to High Latitudes
- `BD::DimArray=nothing`: Dirichlet boundary condition compendium (optional)
"""
function tracer_source_history(t, tracername, box2_box1_ratio, BD = nothing, glob = nothing)

    if tracername == :argon39
        source_func = tracer_point_source_history(tracername)
    else
        source_func = tracer_point_source_history(tracername, BD)

    end

    if tracername ∉ [:Bool, :C14]
        box1 = source_func(t)
        box2 = box2_box1_ratio * box1
        
        # replace this section with a function call.
        boundary_dims = boundary_dimensions()

    return AlgebraicArray([box1,box2],boundary_dims)
    else tracername ∈ [:Bool, :C14]
        b = source_func(t)

        if !isnothing(glob)
            glob .= b
            return glob
        else

            dBD = dims(BD)
            return AlgebraicArray(vec(b), (Ti([t]), dBD[2], dBD[3]))
        end

    end
    
    # replace this section with a function call.
    
end

"""
    evolve_concentration(C₀, A, B, tlist, source_history; halflife = nothing)

Integrate forcing vector over time to compute the concentration history. Find propagator by analytical expression using eigen-methods.

# Arguments
- `C₀`: initial tracer concentration
- `A`: tracer transport information used in matrix calculations
- `B`: boundary condition information used in matrix calculations
- `tlist`: list of times to save tracer concentration
- `source_history::Function`: returns Dirichlet boundary condition at a given time
- `halflife=nothing`: radioactive half life (optional)
"""
function evolve_concentration(C₀, A, B, tlist, source_history; halflife = nothing)

    if isnothing(halflife)
        μ, V = eigen(A)
    else
        Aλ =  linear_probe(tracer_tendency, C₀, halflife)
        μ, V = eigen(A+Aλ)
    end 

    # initial condition contribution
    Ci = deepcopy(C₀)

    # forcing contribution
    Cf = zeros(dims(C₀), :VectorArray)

    # total
    C = DimArray(Array{VectorDimArray}(undef,size(tlist)),Ti(tlist))
    
    C[1] = Ci + Cf
    
    # % Compute solution.
    for tt = 2:length(tlist)
        ti = tlist[tt-1]
        tf = tlist[tt]
        Ci = timestep_initial_condition(C[tt-1], μ, V, ti, tf)

        # Forcing contribution
        
        Cf = integrate_forcing( ti, tf, μ, V, B, source_history)

        # total
        C[tt] = Ci + Cf
    end # tt
    return real.(C) # Cut imaginary part which is zero to machine precision.
end

"""
    timestep_initial_condition(C, μ, V, ti, tf)

# Arguments
- `C::VectorDimArray`: tracer distribution at `ti`
- `μ`: eigenvalue diagonal matrix
- `V`: eigenvector matrix
- `ti`: initial time
- `tf`: final time
# Returns
- `Cf::VectorDimArray`: tracer distribution at `tf`
"""
timestep_initial_condition(C, μ, V, ti, tf) = real.( V * exp(Diagonal(μ)*(tf-ti)) / V * C )

"""
    forcing_integrand(t, tf, μ, V, B, source_history)

Integrand for boundary condition term in equation 10 (Haine et al., 2024).

# Arguments
- `t`: time
- `tf`: final time 
- `μ`: eigenvalue diagonal matrix
- `V`: eigenvector matrix
- `B`: boundary condition matrix
- `source_history::Function`: returns Dirichlet boundary condition at a given time
"""
function forcing_integrand(t, tf, μ, V, B, source_history)
    return real( V * exp(Diagonal(μ)*(tf-t)) / V * B * source_history(t))
end

#forcing_integrand(t, tf, μ, V, B, source_history) = real.( V * exp(Diagonal(μ)*(tf-t)) / V * B * source_history(t))
    
"""
    integrate_forcing(t0, tf, μ, V, B, source_history)

Integrate boundary condition term in equation 10 (Haine et al., 2024).

# Arguments
- `t0`: initial time
- `tf`: final time 
- `μ`: eigenvalue diagonal matrix
- `V`: eigenvector matrix
- `B`: boundary condition matrix
- `source_history::Function`: returns Dirichlet boundary condition at a given time
"""
function integrate_forcing(t0, tf, μ, V, B, source_history)
    forcing_func(t) = forcing_integrand(t, tf, μ, V, B, source_history)
    # MATLAB: integral(integrand,ti,tf,'ArrayValued',true)
    integral, err = quadgk(forcing_func, t0, tf)
    (err < 1e-5) ? (return integral) : error("integration error too large")
end

"""
    tracer_timeseries(tracername, A, B, tlist, mbox1, vbox1; BD=nothing, halflife=nothing)

Simulate tracers and return tracer timeseries from one box.

# Arguments
- `tracername`: name of tracer
- `A`: tracer transport matrix
- `B`: boundary condition matrix
- `tlist`: list of times to save tracer concentration
- `mbox`: name of meridional box of interest
- `vbox`: name of vertical box of interest
- `BD=nothing`: Dirichlet boundary condition
- `halflife=nothing`: radioactive half life
"""
function tracer_timeseries(tracername, A, B, tlist, mbox1, vbox1; BD=nothing, halflife=nothing, glob = nothing)

    if isnothing(halflife) && !isnothing(BD)
        return transient_tracer_timeseries(tracername, A, B, BD, tlist, mbox1, vbox1,glob = glob)
    elseif tracername == :argon39 
        return steady_tracer_timeseries(tracername, A, B, halflife, tlist, mbox1, vbox1)
    elseif tracername ∈ [:iodine129, :C14] && !isnothing(BD)
        return transient_tracer_timeseries(tracername, A, B, BD, tlist, mbox1, vbox1, halflife = halflife,glob = glob)
    end
end

"""
    transient_tracer_timeseries(tracername, A, B, BD, tlist, mbox1, vbox1; halflife = nothing)

Simulate transient tracers and return tracer timeseries from one box.

# Arguments
- `tracername`: name of tracer
- `A`: tracer transport matrix
- `B`: boundary condition matrix
- `BD`: Dirichlet boundary condition
- `tlist`: list of times to save tracer concentration
- `mbox`: name of meridional box of interest
- `vbox`: name of vertical box of interest
- `halflife=nothing`: radioactive half life
"""
function transient_tracer_timeseries(tracername, A, B, BD, tlist, mbox1, vbox1; halflife = nothing, glob = false)

    # fixed parameters for transient tracers
    if tracername == :iodine129
        box2_box1_ratio = 0.25
    elseif  (tracername == :CFC11NH) ||
        (tracername == :CFC12NH) ||
        (tracername == :SF6NH)
        box2_box1_ratio = 0.75
    elseif (tracername ∈ [:Bool, :C14])
        box2_box1_ratio = 1#0.5
    else
        error("transient tracer not implemented")
    end

    
    # all tracers start with zero boundary conditions
    #C₀ = zeros(model_dimensions(), :VectorArray)
    C₀ = zeros(A.data.dims, :VectorArray)
	
    source_history_func(t) =  tracer_source_history(t,
	                                            tracername,
	                                            box2_box1_ratio,
                                                    BD, 
                                                    glob
                                                    )
    Cevolve = evolve_concentration(C₀, 
	                           A,
	                           B,
	                           tlist, 
	                           source_history_func,
                                   halflife = halflife)
    if isnothing(mbox1) && isnothing(vbox1)
        da1 = [Matrix(Cevolve[t].data) for t in eachindex(tlist)]
        return AlgebraicArray(vec(cat(da1..., dims = 3)) , (A.data.dims..., Ti(tlist)))
    else
        return [Cevolve[t][At(mbox1),At(vbox1)] for t in eachindex(tlist)]
    end
    

end

"""
    steady_tracer_timeseries(tracername, A, B, halflife, tlist, mbox1, vbox1)

Simulate non-transient tracers and return tracer timeseries from one box.

# Arguments
- `tracername`: name of tracer
- `A`: tracer transport matrix
- `B`: boundary condition matrix
- `halflife`: radioactive half life
- `BD`: Dirichlet boundary condition
- `tlist`: list of times to save tracer concentration
- `mbox`: name of meridional box of interest
- `vbox`: name of vertical box of interest
"""
function steady_tracer_timeseries(tracername, A, B, halflife, tlist, mbox1, vbox1)

    C₀ = ones(model_dimensions(), :VectorArray) # initial conditions: faster spinup

    if tracername == :argon39 
        box2_box1_ratio = 1 
    
        source_history_func(t) =  tracer_source_history(t,
	    tracername,
	    box2_box1_ratio
        )

        Cevolve = evolve_concentration(C₀, 
	    A,
	    B,
	    tlist, 
	    source_history_func;
	    halflife = halflife)

    else
        error("only implemented for argon-39")
    end
    
    return [Cevolve[t][At(mbox1),At(vbox1)] for t in eachindex(tlist)]

end

