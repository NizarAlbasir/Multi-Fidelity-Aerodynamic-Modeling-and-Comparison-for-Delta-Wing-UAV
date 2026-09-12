% LOAD_AVL_DERIVATIVES
% Reads the AVL all_derivatives.csv and builds a structured array avl.FIELD(iV,iBeta,iAlpha)
%
% Breakpoints:
%   V     : [3 6 9 12 15 18] m/s
%   beta  : [0 5 10 15 20] deg
%   alpha : [-15 -12 -9 -6 -3 0 3 6 9 12 15] deg
%
% Force / moment coefficients:
%   avl.CL, .CD, .CDind, .CY, .Cl, .Cm, .Cn, .e
%
% Stability derivatives (w.r.t. alpha, beta):
%   avl.CLa, .CLb, .CYa, .CYb, .Cla, .Clb, .Cma, .Cmb, .Cna, .Cnb
%
% Dimensionless rate derivatives:
%   avl.CLp, .CLq, .CLr
%   avl.CYp, .CYq, .CYr
%   avl.Clp, .Clq, .Clr
%   avl.Cmp, .Cmq, .Cmr
%   avl.Cnp, .Cnq, .Cnr
%
% Control derivatives (flap, d1):
%   avl.CLd1, .CYd1, .Cld1, .Cmd1, .Cnd1, .CDffd1, .ed1
%
% Other:
%   avl.Xnp, .spiral_stab, .pb2V, .qc2V, .rb2V
%
% Usage:
%   load_avl_derivatives          % loads 'all_derivatives.csv' from current folder
%   load_avl_derivatives('path/to/all_derivatives.csv')
%
% Index access:
%   iV=2; iBeta=1; iAlpha=6;
%   CL_val = avl.CL(iV, iBeta, iAlpha);
%
% Continuous interpolation:
%   CL_val = interpn(avl.V, avl.beta, avl.alpha, avl.CL, 7.5, 5, 2);

% ---- file path -----------------------------------------------------------
if ~exist('avl_filepath','var')
    avl_filepath = 'all_derivatives.csv';
end

% ---- read ----------------------------------------------------------------
fprintf('Reading: %s\n', avl_filepath);
T = readtable(avl_filepath, 'VariableNamingRule', 'preserve');
fprintf('  %d rows loaded.\n', height(T));

% ---- breakpoints ---------------------------------------------------------
V_vec     = unique(T.V,     'sorted');
beta_vec  = unique(T.beta,  'sorted');
alpha_vec = unique(T.alpha, 'sorted');

nV     = numel(V_vec);
nBeta  = numel(beta_vec);
nAlpha = numel(alpha_vec);

fprintf('  V     : %s m/s\n',  num2str(V_vec',     '%.0f '));
fprintf('  beta  : %s deg\n',  num2str(beta_vec',  '%.0f '));
fprintf('  alpha : %s deg\n',  num2str(alpha_vec', '%.0f '));
fprintf('  Grid  : [%d x %d x %d]\n', nV, nBeta, nAlpha);

% ---- fields to extract ---------------------------------------------------
fields = { ...
    'CL','CD','CDind','CY','Cl','Cm','Cn','e', ...           % force/moment
    'CLa','CLb','CYa','CYb','Cla','Clb','Cma','Cmb','Cna','Cnb', ... % alpha/beta derivs
    'CLp','CLq','CLr','CYp','CYq','CYr', ...                 % rate derivs
    'Clp','Clq','Clr','Cmp','Cmq','Cmr','Cnp','Cnq','Cnr', ...
    'CLd1','CYd1','Cld1','Cmd1','Cnd1','CDffd1','ed1', ...   % control derivs
    'Xnp','spiral_stab','pb2V','qc2V','rb2V' };              % other

% ---- pre-allocate --------------------------------------------------------
sz = [nV, nBeta, nAlpha];
for f = fields
    avl.(f{1}) = nan(sz);
end

% ---- fill grid -----------------------------------------------------------
tol = 1e-3;
for k = 1:height(T)
    iV     = find(abs(V_vec     - T.V(k))     < tol, 1);
    iBeta  = find(abs(beta_vec  - T.beta(k))  < tol, 1);
    iAlpha = find(abs(alpha_vec - T.alpha(k)) < tol, 1);

    if isempty(iV) || isempty(iBeta) || isempty(iAlpha), continue; end

    % skip if already filled (handles duplicate rows — keep first)
    if ~isnan(avl.CL(iV, iBeta, iAlpha)), continue; end

    for f = fields
        val = T.(f{1})(k);
        avl.(f{1})(iV, iBeta, iAlpha) = val;
    end
end

% ---- store breakpoints ---------------------------------------------------
avl.V     = V_vec;
avl.beta  = beta_vec;
avl.alpha = alpha_vec;

% ---- report --------------------------------------------------------------
nNaN = sum(isnan(avl.CL(:)));
if nNaN == 0
    fprintf('Done. Grid fully populated — no NaNs.\n');
else
    fprintf('Done. %d NaN entries remain (sparse data).\n', nNaN);
end
fprintf('  Example : avl.Cma(iV, iBeta, iAlpha)\n');
fprintf('  Interp  : interpn(avl.V, avl.beta, avl.alpha, avl.Cma, 9, 0, 3)\n');

clearvars -except avl
