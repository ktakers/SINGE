function [result,AIC_bias,BIC_bias,for_metrics] = iLasso(Series, lambda, krnl,L,dDt,SIG,params)
% Learning teporal dependency among irregular time series ussing Lasso (or its variants)
%
% INPUTS:
%       Series: an Nx1 cell array; one cell for each time series. Each cell
%               is a 2xT matrix. First row contains the values and the
%               second row contains SORTED time stamps. The first time
%               series is the target time series which is predicted.
%       lambda: The regularization parameter in Lasso
%       krnl:   Selects the kernel. Default is Gaussian. Available options
%               are Sinc (krnl = Sinc) and Inverse distance (krnl = Dist).
% OUTPUTS:
%       result: The NxL coefficient matrix.
%       AIC:    The AIC score
%       BIC:    The BIC score
%
% Dependency: This code requires the GLMnet package to perform Lasso.
% For Details of the algorithm please refer to:
% M. T. Bahadori and Yan Liu, "Granger Causality Analysis in Irregular Time Series", (SDM 2012)
addDC = 0;
BIC = 0;
BIC_bias = 0;
AIC_bias = 0;
if addDC
    Series{length(Series)+1} = Series{end};
    Series{end}(1,:) = ones(size(Series{end}(1,:)));
end
% Parameters
L = L/dDt;     % Length of studied lag
L0 = L;
Dt = dDt;
% \Delta t
%SIG = 1;    % Kernel parameter. Here Gaussian Kernel Bandwidth
B = sum(Series{1}(2, :)<=(L*Dt));
N1 = size(Series{1}, 2);
P = length(Series);

% Build the matrix elements
Am = (zeros(N1-B, P*L));
bm = (zeros(N1-B, 1));
% Building the design matrix
for j = 1:P
    for i = (B+1):N1
          bm(i-B) = Series{1}(1, i);
        ti = (Series{1}(2, i) - (L)*Dt):Dt:(Series{1}(2, i)-Dt);
        ti = repmat(ti, length(Series{j}(2, :)), 1);
        tSelect = repmat(Series{j}(2, :)', 1, L0);
        ySelect = repmat(Series{j}(1, :)', 1, L0);
        switch krnl
            case 'Sinc'     % The sinc Kernel
                Kp = sinc((ti-tSelect)/SIG);
            case 'Dist'     % The Dist Kernel
                Kp = SIG./((ti-tSelect).^2);
            otherwise
                Kp = exp(-((ti-tSelect).^2)/SIG);        % The Gaussian Kernel
        end
        Am(i-B, ((j-1)*L0+1):(j*L0) ) = sum(ySelect.*Kp)./sum(Kp);
      end
end
% Solving Lasso using a solver; here the 'GLMnet' package
opt = glmnetSet;
opt.lambda = lambda;
opt.alpha = 1;
[nObs,nVars] = size(Am);
opt.penalty_factor = ones(nVars,1);
j= 1;

%   No sparsity constraint on autoregressive interactions for SCINGE
opt.penalty_factor(((j-1)*L+1):(j*L)) = 0;

fit = glmnet(Am, bm, params.family, opt);
w = fit.beta;

% Computing the BIC and AIC metrics
if 0
BIC = norm(Am*w-bm)^2-log(N1-B)*sum(w==0)/2;
AIC = norm(Am*w-bm)^2-2*sum(w==0)/2;

BIC_bias= norm(Am*w+fit.a0-bm)^2-log(N1-B)*(sum(w==0)+1)/2;
AIC_bias = norm(Am*w+fit.a0-bm)^2-2*(sum(w==0)+1)/2;
end
% Reformatting the output
result = zeros(P, L0);
count = 0; genes = []; areas = [];

% All Genes prediction first
%SmSer{count}(1,:) = Am*w+fit.a0;
%SmSer{count}(2,:) = Series{count}(2,end-length(SmSer{count}(1,:))+1:end);
%chosen = [];chosen_areas=[]; chosen_metrics = [];
%w1 = zeros(size(w));

for_metrics.Am = Am;
for_metrics.bm = bm;
for_metrics.w = w;
for_metrics.a0 = fit.a0;
for_metrics.bic = BIC;
for i = 1:P
    result(i, :) = w((i-1)*L0+1:i*L0);
end