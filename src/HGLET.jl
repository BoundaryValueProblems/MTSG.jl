module HGLET

include("utils.jl")

using ..GraphSignal, ..GraphPartition, ..BasisSpecification, ..GHWT

include("common.jl")

export HGLET_Synthesis, HGLET_jkl, HGLET_Analysis_All, HGLET_GHWT_BestBasis, BSfull, HGLET_GHWT_Synthesis, HGLET_GHWT_BestBasis_minrelerror


"""
    function HGLET_Synthesis(dvec::Vector{Float64}, GP::GraphPart, BS::BasisSpec, G::GraphSig; method::Symbol = :L)

Add noise to the data of a GraphSig object

### Input Arguments
* `dvec`: the expansion coefficients corresponding to the chosen basis
* `GP`: a GraphPart object
* `BS`: a BasisSpec object
* `G`: a GraphSig object
* `method`: :L, :Lrw, or :Lsym, indicating which eigenvectors are used

### Output Argument
* `f`: the reconstructed signal
* `GS`: the reconstructed GraphSig object
"""


function HGLET_Synthesis(dvec::Matrix{Float64}, GP::GraphPart, BS::BasisSpec, G::GraphSig; method::Symbol = :L)
    # Preliminaries

    # constants
    jmax = size(GP.rs,2)

    # fill in the appropriate entries of dmatrix
    dmatrix = dvec2dmatrix(dvec,GP,BS)

    f = dmatrix[:,jmax,:]

    W = G.W

    # Perform the synthesis transform ==> eigenvectors of L
    if method != :Lrw && method != :Lsym
        for j = jmax:-1:1
            regioncount = countnz(GP.rs[:,j]) - 1
            for r = 1:regioncount
                # the index that marks the start of the region
                rs1 = GP.rs[r,j]

                # the index that is one after the end of the region
                rs3 = GP.rs[r+1,j]

                # the number of points in the current region
                n = rs3 - rs1

                # only proceed forward if coefficients do not exist

                if (j == jmax || countnz(dmatrix[rs1:rs3-1,j+1,:]) == 0) && countnz(dmatrix[rs1:rs3-1,j,:]) > 0

                    if n == 1
                        f[rs1,:] = dmatrix[rs1,j,:]
                    elseif n > 1
                        indrs = GP.ind[rs1:rs3-1]

                        # compute the eigenvectors of L ==> svd(L)
                        vec,_,_ = svd(diagm(squeeze(sum(W[indrs,indrs],1),1))-W[indrs,indrs])
                        vec = vec[:,end:-1:1]

                        # standardize the eigenvector signs
                        for col = 1:n
                            row = 1
                            standardized = false
                            while !standardized
                                if vec[row,col] > 10^3*eps()
                                    standardized = true
                                elseif vec[row,col] < -10^3*eps()
                                    vec[:,col] = - vec[:,col]
                                else
                                    row = row + 1
                                end
                            end
                        end

                        # reconstruct the signal
                        f[rs1:rs3-1,:] = vec * dmatrix[rs1:rs3-1,j,:]

                    end
                end
            end
        end
    elseif method == :Lrw
        for j = jmax:-1:1
            regioncount = countnz(GP.rs[:,j]) - 1
            for r = 1:regioncount
                # the index that marks the start of the region
                rs1 = GP.rs[r,j]

                # the index that is one after the end of the region
                rs3 = GP.rs[r+1,j]

                # the number of points in the current region
                n = rs3 - rs1

                # only proceed forward if coefficients do not exist

                if (j == jmax || countnz(dmatrix[rs1:rs3-1,j+1,:]) == 0) && countnz(dmatrix[rs1:rs3-1,j,:]) > 0

                    if n == 1
                        f[rs1,:] = dmatrix[rs1,j,:]
                    elseif n > 1
                        indrs = GP.ind[rs1:rs3-1]

                        if minimum(sum(W[indrs,indrs],1)) > 10^3*eps()
                            useLrw = true

                            ### eigenvectors of L_rw ==> svd(L_sym)
                            W_temp = W[indrs,indrs]
                            D_temp = spdiagm(squeeze(sum(W_temp,1),1))
                            D_temp_p = spdiagm(squeeze(sum(W_temp,1),1).^(-1/2))
                            vec,_,_ = svd(full(D_temp_p*(D_temp - W_temp)*D_temp_p))
                            vec = vec[:,end:-1:1]

                        else
                            useLrw = false

                            ### eigenvectors of L ==> svd(L)
                            vec,_,_ = svd(full(D_temp-W_temp))
                            vec = vec[:,end:-1:1]
                        end

                        #standardized the eigenvector signs
                        for col = 1:n
                            row = 1
                            standardized = false
                            while !standardized
                                if vec[row,col] > 10^3*eps()
                                    standardized = true
                                elseif vec[row,col] < -10^3*eps()
                                    vec[:,col] = - vec[:,col]
                                else
                                    row = row + 1
                                end
                            end
                        end

                        # reconstruct the signal
                        if useLrw
                            f[rs1:rs3-1,:] = D_temp_p*vec*dmatrix[rs1:rs3-1,j,:]
                        else
                            f[rs1:rs3-1,:] = vec*dmatrix[rs1:rs3-1,j,:]
                        end
                    end
                end
            end
        end
    elseif method == :Lsym
        for j = jmax:-1:1
            regioncount = countnz(GP.rs[:,j]) - 1
            for r = 1:regioncount
                # the index that marks the start of the region
                rs1 = GP.rs[r,j]

                # the index that is one after the end of the region
                rs3 = GP.rs[r+1,j]

                # the number of points in the current region
                n = rs3 - rs1

                # only proceed forward if coefficients do not exist

                if (j == jmax || countnz(dmatrix[rs1:rs3-1,j+1,:]) == 0) && countnz(dmatrix[rs1:rs3-1,j,:]) > 0

                    if n == 1
                        f[rs1,:] = dmatrix[rs1,j,:]
                    elseif n > 1
                        indrs = GP.ind[rs1:rs3-1]

                        if minimum(sum(W[indrs,indrs],1)) > 10^3*eps()
                            useLrw = true

                            ### eigenvectors of L_rw ==> svd(L_sym)
                            W_temp = W[indrs,indrs]
                            D_temp = spdiagm(squeeze(sum(W_temp,1),1))
                            D_temp_p = spdiagm(squeeze(sum(W_temp,1),1).^(-1/2))
                            vec,_,_ = svd(full(D_temp_p*(D_temp - W_temp)*D_temp_p))
                            vec = vec[:,end:-1:1]

                        else
                            useLrw = false

                            ### eigenvectors of L ==> svd(L)
                            vec,_,_ = svd(full(D_temp-W_temp))
                            vec = vec[:,end:-1:1]
                        end

                        #standardized the eigenvector signs
                        for col = 1:n
                            row = 1
                            standardized = false
                            while !standardized
                                if vec[row,col] > 10^3*eps()
                                    standardized = true
                                elseif vec[row,col] < -10^3*eps()
                                    vec[:,col] = - vec[:,col]
                                else
                                    row = row + 1
                                end
                            end
                        end

                        # reconstruct the signal
                            f[rs1:rs3-1,:] = vec*dmatrix[rs1:rs3-1,j,:]
                        end
                    end
                end
            end
        end

    # put the reconstructed values in the correct order
    f[GP.ind,:] = f

    # creat a GraphSig object with the reconstructed data
    GS = deepcopy(G)
    replace_data!(GS,f)

    return f, GS
end

"""
    function HGLET_jkl(GP::GraphPart, drow::Int, dcol::Int)

Generate the (j,k,l) indices for the HGLET basis vector corresponding to the coefficient dmatrix(drow,dcol)

### Input Arguments
* `GP`: a GraphPart object
* `drow`: the row of the expansion coefficient
* `dcol`: the column of the expansion coefficient

### Output Argument
* `j`: the level index of the expansion coefficient
* `k`: the subregion index of the expansion coefficient
* `l`: the eigenvector index of the expansion coefficient
"""
function HGLET_jkl(GP::GraphPart, drow::Int, dcol::Int)
    j = dcol - 1

    k = find(GP.rs[:,dcol] .> drow)
    k = k-2

    l = drow - GP.rs[k+1,dcol]

    return j,k,l
end

"""
    function HGLET_Analysis_All(G::GraphSig, GP::GraphPart)

For a GraphSig object 'G', generate the 3 matrices of HGLET expansion coefficients
corresponding to the eigenvectors of L, Lrw and Lsym

### Input Arguments
* `G`:  a GraphSig object
* `GP`: a GraphPart object

### Output Argument
* `dmatrixH`:        the matrix of expansion coefficients for L
* `dmatrixHrw`:      the matrix of expansion coefficients for Lrw
* `dmatrixHsym`:     the matrix of expansion coefficients for Lsym
* `GP`:              a GraphPart object
"""
function HGLET_Analysis_All(G::GraphSig, GP::GraphPart)
    # Preliminaries
    W = G.W
    ind = GP.ind
    rs = GP.rs
    method = GP.method
    N = size(G.W,1)
    jmax = size(rs,2)
    fcols = size(G.f,2)
    dmatrixH = zeros(N,jmax,fcols)
    dmatrixH[:,jmax,:] = G.f[ind,:]
    dmatrixHrw = deepcopy(dmatrixH)
    dmatrixHsym = deepcopy(dmatrixH)

    #Perform the transform ==> eigenvectors of L
    for j = jmax-1:-1:1
        regioncount = countnz(rs[:,j]) - 1
        for r = 1:regioncount
            # the index that marks the start of the region
            rs1 = rs[r,j]

            # the index that is one after the end of the region
            rs3 = rs[r+1,j]

            # the number of points in the current region
            n = rs3-rs1

            if n == 1
                dmatrixH[rs1,j,:] = G.f[ind[rs1],:]

            elseif n > 1
                indrs = ind[rs1:rs3-1]

                # compute the eigenvectors of L ==> svd(L)
                vec,_,_ = svd(diagm(squeeze(sum(W[indrs,indrs],1),1))-W[indrs,indrs])
                vec = vec[:,end:-1:1]

                # standardize the eigenvector signs
                for col = 1:n
                    row = 1
                    standardized = false
                    while !standardized
                        if vec[row,col] > 10^3*eps()
                            standardized = true
                        elseif vec[row,col] < -10^3*eps()
                            vec[:,col] = - vec[:,col]
                        else
                            row = row + 1
                        end
                    end
                end

                # obtain the expansion coefficients
                dmatrixH[rs1:rs3-1,j,:] = vec'*G.f[indrs,:]
            end
        end
    end

    for j = jmax-1:-1:1
        regioncount = countnz(rs[:,j])-1
        for r = 1:regioncount
            # the index that marks the start of the region
            rs1 = rs[r,j]

            # the index that is one after the end of the region

            rs3 = rs[r+1,j]

            # the number of points in the current region
            n = rs3 - rs1

            if n == 1
                dmatrixHrw[rs1,j,:] = G.f[ind[rs1],:]
                dmatrixHsym[rs1,j,:] = G.f[ind[rs1],:]

            elseif n > 1
                indrs = ind[rs1:rs3-1]

                # compute the eigenvectors
                if minimum(sum(W[indrs,indrs],1)) > 10^3*eps()
                    useLrw = true

                    ### eigenvectors of L_rw ==> svd(L_sym)
                    W_temp = W[indrs,indrs]
                    D_temp = spdiagm(squeeze(sum(W_temp,1),1))
                    D_temp_p = spdiagm(squeeze(sum(W_temp,1),1).^(-1/2))
                    vec,_,_ = svd(full(D_temp_p*(D_temp - W_temp)*D_temp_p))
                    vec = vec[:,end:-1:1]

                else
                    useLrw = false

                    ### eigenvectors of L ==> svd(L)
                    vec,_,_ = svd(full(D_temp-W_temp))
                    vec = vec[:,end:-1:1]
                end

                #standardized the eigenvector signs
                for col = 1:n
                    row = 1
                    standardized = false
                    while !standardized
                        if vec[row,col] > 10^3*eps()
                            standardized = true
                        elseif vec[row,col] < -10^3*eps()
                            vec[:,col] = - vec[:,col]
                        else
                            row = row + 1
                        end
                    end
                end

                # obtain the expansion coefficients for L_sym
                dmatrixHsym[rs1:rs3-1,j,:] = vec'*G.f[indrs,:]

                # obtain the expansion coeffcients for L_rw
                if useLrw
                    dmatrixHrw[rs1:rs3-1,j,:] = vec'*diagm(squeeze(sum(W_temp,1),1).^(1/2))*G.f[indrs,:]
                else
                    dmatrixHrw[rs1:rs3-1,j,:] = vec'*G.f[indrs,:]
                end

            end
        end
    end

    return dmatrixH, dmatrixHrw, dmatrixHsym

end


"""
    function HGLET_GHWT_BestBasis(GP::GraphPart; dmatrixH::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixHrw::Array{Float64,3} = Array{Float64,3}(0,0,0)
    ,dmatrixHsym::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixG::Array{Float64,3} = Array{Float64,3}(0,0,0), costfun::Any = 0.1,flatten::Any = 1)

Select the best basis from several matrices of expansion coefficients

### Input Arguments
* `dmatrixH`:    the matrix of HGLET expansion coefficients ==> eigenvectors of L
* `dmatrixHrw`:  the matrix of HGLET expansion coefficients ==> eigenvectors of Lrw
* `dmatrixHsym`: the matrix of HGLET expansion coefficients ==> eigenvectors of Lsym
* `dmatrixG`:    the matrix of GHWT expansion coefficients
* `GP`:          a GraphPart object
* `costfun`:     the cost functional to be used
* `flatten`:     the method for flattening vector-valued data to scalar-valued data

### Output Argument
* `dvec`:     the vector of expansion coefficients corresponding to the bestbasis
* `BS`:       a BasisSpec object which specifies the best-basis
* `trans`:    specifies which transform was used for that portion of the signal:
                   00 = HGLET with L
                   01 = HGLET with Lrw
                   10 = HGLET with Lsym
                   11 = GHWT
"""

function HGLET_GHWT_BestBasis(GP::GraphPart; dmatrixH::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixHrw::Array{Float64,3} = Array{Float64,3}(0,0,0)
,dmatrixHsym::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixG::Array{Float64,3} = Array{Float64,3}(0,0,0), costfun::Any = 0.1,flatten::Any = 1)
    # specify transform codes
    transHsym = [true false]
    transG = [true true]
    transHrw = [false true]
    transH = [false false]

    # the cost functional to be used
    costfun = cost_functional(costfun)

    # constants and dmatrix cleanup
    if !isempty(dmatrixHsym)
        N, jmax, fcols = size(dmatrixHsym)
        dmatrixHsym[abs.(dmatrixHsym).<10^2*eps()] = 0
    end
    if !isempty(dmatrixG)
        N, jmax, fcols = size(dmatrixG)
        dmatrixG[abs.(dmatrixG).<10^2*eps()] = 0
    end
    if !isempty(dmatrixHrw)
        N, jmax, fcols = size(dmatrixHrw)
        dmatrixHrw[abs.(dmatrixHrw).<10^2*eps()] = 0
    end
    if !isempty(dmatrixH)
        N, jmax, fcols = size(dmatrixH)
        dmatrixH[abs.(dmatrixH).<10^2*eps()] = 0
    end

    # flatten dmatrix
    if fcols > 1
        if !isempty(dmatrixHsym)
            dmatrix0Hsym = deepcopy(dmatrixHsym)
            dmatrixdHsym = squeeze(dmatrix_flatten(dmatrixHsym,flatten),1)
        end
        if !isempty(dmatrixG)
            dmatrix0G = deepcopy(dmatrixG)
            dmatrixG = squeeze(dmatrix_flatten(dmatrixG,flatten),1)
        end
        if !isempty(dmatrixHrw)
            dmatrix0Hrw = deepcopy(dmatrixHrw)
            dmatrixHrw = squeeze(dmatrix_flatten(dmatrixHrw,flatten),1)
        end
        if !isempty(dmatrixH)
            dmatrix0H = deepcopy(dmatrixH)
            dmatrixH = squeeze(dmatrix_flatten(dmatrixH,flatten),1)
        end
    end

    # Find the HGLET/GHWT best-basis

    # allocate/initialize ==> order matters here
    if !isempty(dmatrixHsym)
        dvec = dmatrixHsym[:,jmax]
        trans = repmat(transHsym,N,1)
    end
    if !isempty(dmatrixG)
        dvec = dmatrixG[:,jmax]
        trans = repmat(transG,N,1)
    end
    if !isempty(dmatrixHrw)
        dvec = dmatrixHrw[:,jmax]
        trans = repmat(transHrw,N,1)
    end
    if !isempty(dmatrixH)
        dvec = dmatrixH[:,jmax]
        trans = repmat(transH,N,1)
    end
    levlist = jmax*ones(Int,N)

    # set the tolerance
    tol = 10^4*eps()

    # perform the basis search
    for j = jmax:-1:1
        regioncount = countnz(GP.rs[:,j]) - 1
        for r = 1:regioncount
            indr = GP.rs[r,j]:(GP.rs[r+1,j]-1)
            ### compute the cost of the current best basis
            costBB = costfun(dvec[indr])

            ### compute the cost of the HGLET-Lsym coefficients
            if !isempty(dmatrixHsym)
                costNew = costfun(dmatrixHsym[indr,j])
                # change the best basis if the new cost is less expensive
                if costBB >= costNew - tol
                    costBB, dvec[indr], levlist[indr], trans[indr,:] = BBchange(costNew, dmatrixHsym[indr,j],j,transHsym)
                end
            end

            ### compute the cost of the GHWT coefficients
            if !isempty(dmatrixG)
                costNew = costfun(dmatrixG[indr,j])
                # change the best basis if the new cost is less expensive
                if costBB >= costNew - tol
                    costBB, dvec[indr], levlist[indr], trans[indr,:] = BBchange(costNew, dmatrixG[indr,j],j,transG)
                end
            end

            ### compute the cost of the GHWT coefficients
            if !isempty(dmatrixHrw)
                costNew = costfun(dmatrixHrw[indr,j])
                # change the best basis if the new cost is less expensive
                if costBB >= costNew - tol
                    costBB, dvec[indr], levlist[indr], trans[indr,:] = BBchange(costNew, dmatrixHrw[indr,j],j,transHrw)
                end
            end

            ### compute the cost of the HGLET-L coefficients
            if !isempty(dmatrixH)
                costNew = costfun(dmatrixH[indr,j])
                # change the best basis if the new cost is less expensive
                if costBB >= costNew - tol
                    _, dvec[indr],levlist[indr],trans[indr,:] = BBchange(costNew, dmatrixH[indr,j],j,transH)
                end
            end
        end
    end

    transfull = deepcopy(trans)
    trans = trans[levlist.!=0,:]
    levlist = levlist[levlist.!=0]

    BS = BasisSpec(levlist,c2f = true, description = "HGLET-GHWT Best Basis")
    levlist2levlengths!(GP,BS)

    # if we flattened dmatrix, then "unflatten" the expansion coefficients
    if fcols > 1
        # create vectors of coefficients (which are zero if the transform's coefficients were not included as function inputs)
        if !isempty(dmatrixH)
            dvecH = dmatrix2dvec(dmatrix0H,GP,BS)
        else
            dvecH = zeros(N,fcols)
        end
        if !isempty(dmatrixHrw)
            dvecHrw = dmatrix2dvec(dmatrix0Hrw,GP,BS)
        else
            dvecHrw = zeros(N,fcols)
        end
        if !isempty(dmatrixHsym)
            dvecHsym = dmatrix2dvec(dmatrix0Hsym,GP,BS)
        else
            dvecHsym = zeros(N,fcols)
        end
        if !isempty(dmatrixG)
            dvecG = dmatrix2dvec(dmatrix0G,GP,BS)
        else
            dvecG = zeros(N,fcols)
        end

        dvec = dvecHsym.*(transfull[:,1].*(.~transfull[:,2]))
        + dvecG.*(transfull[:,1].*transfull[:,2])
        + dvecHrw.*((.~transfull[:,1]).*transfull[:,2])
        + dvecH.*((.~transfull[:,1]).*(.~transfull[:,2]))
    end

    return dvec,BS, trans

end


function BBchange(costNew::Float64, dvec::Vector{Float64}, j::Int, trans::Array{Bool,2})
    #change to the new best basis
    costBB = costNew

    n = length(dvec)

    levlist = zeros(Int,n,1)
    levlist[1] = j

    trans = repmat(trans,n,1)

    return costBB, dvec, levlist, trans
end



"""
    function BSfull(GP, BS, trans)
    Given a BasisSpec object, return the full-length, redundant levlist, levlengths, and trans description

### Input Arguments
    * `GP`:         A GraphPart object
    * `BS`:         A BasisSpec object
    * `trans`:      A specification of the transforms used for the HGLET-GHWT hybrid transform

### Output Argument
    * `levlistfull`:    the full-length, redundant levels list description
    * `levlengthsfull`: the full-length, redundant levels lengths description
    * `transfull`:      the full-length, redundant trans description
"""
function BSfull(GP::GraphPart, BS::BasisSpec, trans::Array{Bool,2})
    ## 0. Preliminaries

    # extract data
    levlist = BS.levlist
    levlengths = BS.levlengths

    # allocate space
    N = length(GP.ind)
    levlistfull = zeros(Int,N,1)
    levlengthsfull = zeros(Int,N,1)
    cols = size(trans,2)
    transfull = falses(N,cols)


    ## 1. Fill out the redundant descriptions
    ind = 0
    for row  = 1:length(BS_temp.levlist)
        levlistfull[ind+1:ind+levlengths[row]] = levlist[row]

        levlengthsfull[ind+1:ind+levlengths[row]] = levlengths[row]

        transfull[ind+1:ind+levlengths[row],:] = repmat(trans[[row],:],levlengths[row],1)

        ind = ind + levlengths[row]
    end
    return levlistfull, levlengthsfull, transfull
end



"""
    function HGLET_GHWT_Synthesis(dvec::Array{float,2},GP::GraphPart,BS::BasisSpec,trans::Array{Bool,2},G::GraphSig)
    Given a vector of HGLET & GHWT expansion coefficients, info about the
    graph partitioning, and the choice of basis and corresponding transforms,
    reconstruct the signal

### Input Arguments
    * `dvec`:         the expansion coefficients corresponding to the chosen basis
    * `GP`:         A GraphPart object
    * `BS`:         A BasisSpec object
    * `trans`:      A specification of the transforms used for the HGLET-GHWT hybrid transform
                00 = HGLET with L
                01 = HGLET with Lrw
                10 = HGLET with Lsym
                11 = GHWT
    * `G`:          A GraphSig object

### Output Argument
    * `f`:    the reconstructed signal
    * `GS`:   the reconstructed GraphSig object
"""
function HGLET_GHWT_Synthesis(dvec::Array{Float64,2},GP::GraphPart,BS::BasisSpec,trans::Array{Bool,2},G::GraphSig)
# fill out trans
_,_,transfull = BSfull(GP,BS,trans)

# decompose dvec into GHWT and HGLET components
dvecHsym= dvec.*(transfull[:,1].*(.~transfull[:,2]))
dvecG   = dvec.*(transfull[:,1].*transfull[:,2])
dvecHrw = dvec.*((.~transfull[:,1]).*transfull[:,2])
dvecH   = dvec.*((.~transfull[:,1]).*(.~transfull[:,2]))

# Synthesize using the transforms separately

fH,_ = HGLET_Synthesis(dvecH, GP, BS, G)
fHrw,_ = HGLET_Synthesis(dvecHrw, GP, BS, G, method = :Lrw)
fHsym,_ = HGLET_Synthesis(dvecHsym, GP, BS, G, method = :Lsym)
fG = ghwt_synthesis(dvecG, GP, BS)

f = fH + fHrw +fHsym + fG

GS = deepcopy(G)
replace_data!(GS,f)

return f, GS

end


"""
    function HGLET_GHWT_BestBasis_minrelerror(GP::GraphPart,G::GraphSig;dmatrixH::Array{Float64,3} = Array{Float64,3}(0,0,0), dmatrixHrw::Array{Float64,3} = Array{Float64,3}(0,0,0),
        dmatrixHsym::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixG::Array{Float64,3} = Array{Float64,3}(0,0,0), compare::Bool = true)

    Find the best basis for approximating the signal 'G' by performing the best basis search with a range of tau-measures
    as cost functionals (tau = 0.1,0.2,...,1.9) and minimizing the relative error.

    ### Input argument:
    * `dmatrixH`: the matrix of HGLET expansion coefficients ==> eigenvectors of L
    * `dmatrixHrw`: the matrix of HGLET expansion coefficients ==> eigenvectors of Lrw
    * `dmatrixHsym`: the matrix of HGLET expansion coefficients ==> eigenvectors of Lsym
    * `dmatrixG`: the matrix of GHWT expansion coefficients
    * `GP`: a GraphPart object
    * `G`: the GraphSig object
    * `compare`: if it is false, don't compare the hybrid best basis to the GHWT fine-to-coarse best basis

    ### Output argument:
    * `dvec`: the vector of expansion coefficients corresponding to the bestbasis
    * `BS`: a BasisSpec object which specifies the best-basis
    * `trans`: specifies which transform was used for that portion of the signal
        00 = HGLET with L
        01 = HGLET with Lrw
        10 = HGLET with Lsym
        11 = GHWT
    * `tau`: the tau that yields the smallest relative error

"""
function HGLET_GHWT_BestBasis_minrelerror(GP::GraphPart,G::GraphSig;dmatrixH::Array{Float64,3} = Array{Float64,3}(0,0,0), dmatrixHrw::Array{Float64,3} = Array{Float64,3}(0,0,0),
    dmatrixHsym::Array{Float64,3} = Array{Float64,3}(0,0,0),dmatrixG::Array{Float64,3} = Array{Float64,3}(0,0,0), compare::Bool = true)
    dvec, BS, trans, tau = 0, 0, 0, 0 # predefine
    sumrelerror = Inf
    for tau_temp = 0.1:0.1:1.9
        # we are only considering the GHWT
        if isempty(dmatrixH) && isempty(dmatrixHrw) && isempty(dmatrixHsym) && !isempty(dmatrixG)
            dvec_temp, BS_temp = ghwt_bestbasis(dmatrixG, GP, cfspec = tau_temp)
            trans_temp = trues(length(BS_temp.levlist,2))
            orthbasis = true
        else
            dvec_temp, BS_temp, trans_temp = HGLET_GHWT_BestBasis(GP, dmatrixH = dmatrixH, dmatrixG = dmatrixG,
            dmatrixHrw = dmatrixHrw, dmatrixHsym = dmatrixHsym, costfun = tau_temp)

            # check whether any HGLET Lrw basis vectors are in the best basis
            orthbasis = true
            rows = size(trans_temp,1)
            for row = 1:rows
                if !trans_temp[row,1] && trans_temp[row,2]
                    orthbasis = false
                    break
                end
            end
        end

        # compute the relative errors
        if orthbasis
            relerror_temp = orth2relerror(dvec_temp)
        else
            B = HGLET_GHWT_Synthesis(eye(length(dvec_temp)),GP,BS_temp,trans_temp,G)
            relerror_temp = nonorth2relerror(dvec_temp,B)
        end
        sumrelerror_temp = sum(relerror_temp)

        # consider the GHWT fine-to-coarse best basis
        if compare == true && !isempty(dmatrixG)
            dvec_f2c, BS_f2c = ghwt_f2c_bestbasis(dmatrixG, GP, cfspec = tau_temp)
            sumrelerror_f2c = sum(orth2relerror(dvec_f2c))
            if sumrelerror_f2c < sumrelerror_temp
                sumrelerror_temp = sumrelerror_f2c
                dvec_temp = copy(dvec_f2c)
                BS_temp = deepcopy(BS_f2c)
                trans_temp = repmat([true true], length(BS_f2c.levlist),1)
            end
        end

        # compare to the current lowest sum of relative errors
        if  sumrelerror_temp < sumrelerror
            dvec = copy(dvec_temp)
            BS = deepcopy(BS_temp)
            trans = copy(trans_temp)
            sumrelerror = sumrelerror_temp
            tau = tau_temp
        end
    end
    return dvec, BS, trans, tau
end

end # end of module HGLET