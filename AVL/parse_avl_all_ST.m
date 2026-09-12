% =========================================================
%  parse_avl_all_ST.m
%  Auto-discovers all run_XX_caseYY_ST.txt files,
%  parses every one, and builds a single flat table.
%
%  HOW TO USE:
%  1. Set ST_DIR to the folder containing your ST files
%  2. Run
% =========================================================

clear; clc;

% ── STEP 1: folder containing all *_ST.txt files ─────────
ST_DIR = 'V-a-b';    % <-- change this path
% ─────────────────────────────────────────────────────────

files = dir(fullfile(ST_DIR, '*_ST.txt'));
if isempty(files)
    error('No *_ST.txt files found in: %s', ST_DIR);
end

names = {files.name};
files = files(natural_sort_idx(names));
nFiles = numel(files);
fprintf('Found %d ST files. Parsing...\n\n', nFiles);

rows   = cell(nFiles, 1);
n_ok   = 0;

for k = 1:nFiles
    fpath = fullfile(ST_DIR, files(k).name);
    s     = parse_avl_file(fpath);

    if isempty(s)
        warning('Skipping (bad format): %s', files(k).name);
        continue
    end

    tok = regexp(files(k).name, 'run_(\d+)_case(\d+)', 'tokens');
    if ~isempty(tok)
        s.run_num  = str2double(tok{1}{1});
        s.case_num = str2double(tok{1}{2});
    else
        s.run_num  = NaN;
        s.case_num = NaN;
    end

    n_ok        = n_ok + 1;
    rows{n_ok}  = s;
end

rows = rows(1:n_ok);
if n_ok == 0, error('No files were successfully parsed.'); end

% ── Build table ───────────────────────────────────────────
field_names = fieldnames(rows{1});
field_names = field_names(~strcmp(field_names, 'ctrl'));

T = table();
for f = 1:numel(field_names)
    fn   = field_names{f};
    vals = cellfun(@(r) r.(fn), rows, 'UniformOutput', false);
    if isnumeric(vals{1})
        T.(fn) = cell2mat(vals);
    else
        T.(fn) = string(vals);
    end
end

ctrl_fields = fieldnames(rows{1}.ctrl);
for f = 1:numel(ctrl_fields)
    fn     = ctrl_fields{f};
    T.(fn) = cellfun(@(r) r.ctrl.(fn), rows);
end

T = sortrows(T, {'run_num','case_num'});

fprintf('Parsed %d / %d files successfully.\n\n', n_ok, nFiles);
disp(T(:, {'run_num','case_num','alpha','beta','V','CL','CD','Cm', ...
           'CLa','Cma','Cmq','Clb','Cnb','Clp','Cnr'}));

mat_out = fullfile(ST_DIR, 'all_derivatives.mat');
csv_out = fullfile(ST_DIR, 'all_derivatives.csv');
save(mat_out, 'T');
writetable(T, csv_out);
fprintf('\nSaved:\n  %s\n  %s\n', mat_out, csv_out);
fprintf('Table size: %d rows x %d columns\n', height(T), width(T));


% =========================================================
%  PARSING FUNCTIONS
% =========================================================

function s = parse_avl_file(fpath)
    s = [];
    fid = fopen(fpath, 'r');
    if fid < 0, return; end
    raw = textscan(fid, '%s', 'Delimiter', '\n', 'WhiteSpace', '');
    fclose(fid);
    L = raw{1};

    % Must contain the forces block
    if ~any(cellfun(@(l) contains(l,'Vortex Lattice Output'), L)), return; end

    s = empty_case();
    [~, fname, ext] = fileparts(fpath);
    s.filename = [fname ext];

    % ── Locate the LAST occurrence of the forces block ───
    % When ST files contain full AVL console output, the block
    % may appear more than once. The last one is the real result.
    force_idx = find(cellfun(@(l) contains(l,'Vortex Lattice Output'), L));
    force_idx = force_idx(end);   % use the last clean block

    % Work only on lines from that block onward
    Lf = L(force_idx:end);

    % ── Locate the stability-axis section ────────────────
    stab_idx = find(cellfun(@(l) contains(l,'Stability-axis derivatives'), Lf), 1);

    % ── Parse metadata and total forces from Lf ──────────
    idx = find(cellfun(@(l) contains(l,'Run case:'), Lf), 1);
    if ~isempty(idx)
        s.run_case = strtrim(regexprep(Lf{idx}, 'Run case:', ''));
    end

    s.Sref = grep_val(Lf, 'Sref\s*=\s*([\d.]+)');
    s.Cref = grep_val(Lf, 'Cref\s*=\s*([\d.]+)');
    s.Bref = grep_val(Lf, 'Bref\s*=\s*([\d.]+)');
    s.Xref = grep_val(Lf, 'Xref\s*=\s*([\d.]+)');

    s.alpha = grep_val(Lf, 'Alpha\s*=\s*([-\d.]+)');
    s.beta  = grep_val(Lf, 'Beta\s*=\s*([-\d.]+)');
    s.Mach  = grep_val(Lf, 'Mach\s*=\s*([\d.]+)');
    s.pb2V  = grep_val(Lf, 'pb/2V\s*=\s*([-\d.]+)');
    s.qc2V  = grep_val(Lf, 'qc/2V\s*=\s*([-\d.]+)');
    s.rb2V  = grep_val(Lf, 'rb/2V\s*=\s*([-\d.]+)');

    tok = regexp(s.run_case, 'V=\s*([\d.]+)',  'tokens'); if ~isempty(tok), s.V      = str2double(tok{1}{1}); end
    tok = regexp(s.run_case, 'r=\s*([\d.]+)',  'tokens'); if ~isempty(tok), s.r_rate = str2double(tok{1}{1}); end
    tok = regexp(s.run_case, 'p=\s*([\d.]+)',  'tokens'); if ~isempty(tok), s.p_rate = str2double(tok{1}{1}); end
    tok = regexp(s.run_case, 'q=\s*([\d.]+)',  'tokens'); if ~isempty(tok), s.q_rate = str2double(tok{1}{1}); end

    s.CL    = grep_val(Lf, 'CLtot\s*=\s*([-\d.]+)');
    s.CD    = grep_val(Lf, 'CDtot\s*=\s*([-\d.]+)');
    s.CDind = grep_val(Lf, 'CDind\s*=\s*([-\d.]+)');
    s.CY    = grep_val(Lf, 'CYtot\s*=\s*([-\d.]+)');
    s.Cl    = grep_val(Lf, 'Cltot\s*=\s*([-\d.]+)');
    s.Cm    = grep_val(Lf, 'Cmtot\s*=\s*([-\d.]+)');
    s.Cn    = grep_val(Lf, 'Cntot\s*=\s*([-\d.]+)');
    s.e     = grep_val(Lf, 'e\s*=\s*([\d.]+)\s*\|\s*Plane');

    % ── Parse stability derivatives from stab section only ─
    if isempty(stab_idx)
        % No stability section found — derivatives stay NaN
        s.ctrl = struct();
        return
    end

    Ls = Lf(stab_idx:end);   % lines from "Stability-axis" onward

    % Each derivative line looks like:
    %   " z' force CL |    CLa =   3.709985    CLb =  -0.000493"
    % Extract ALL "NAME = VALUE" pairs from these lines
    deriv_pattern = '([A-Za-z][A-Za-z0-9_'']*)\s*=\s*([-\d.]+)';

    % Known derivative names to extract
    deriv_names = { ...
        'CLa','CLb','CYa','CYb','Cla','Clb','Cma','Cmb','Cna','Cnb', ...
        'CLp','CLq','CLr','CYp','CYq','CYr', ...
        'Clp','Clq','Clr','Cmp','Cmq','Cmr','Cnp','Cnq','Cnr'};

    % Build a map from all name=value pairs in the stab section
    deriv_map = containers.Map('KeyType','char','ValueType','double');
    for i = 1:numel(Ls)
        tokens = regexp(Ls{i}, deriv_pattern, 'tokens');
        for j = 1:numel(tokens)
            nm  = tokens{j}{1};
            val = str2double(tokens{j}{2});
            if ~isnan(val)
                deriv_map(nm) = val;
            end
        end
    end

    % Assign to struct
    for d = 1:numel(deriv_names)
        nm = deriv_names{d};
        if isKey(deriv_map, nm)
            s.(nm) = deriv_map(nm);
        end
    end

    % Neutral point & spiral stability (after stab section)
    s.Xnp         = grep_val(Ls, 'Neutral point\s+Xnp\s*=\s*([-\d.]+)');
    s.spiral_stab = grep_val(Ls, 'Clb Cnr / Clr Cnb\s*=\s*([-\d.]+)');

    % Control derivatives  (CLd1, Cmd1, etc.)
    ctrl_lines = Ls(cellfun(@(l) ~isempty(regexp(l, '[A-Za-z]+d\d+\s*=', 'once')), Ls));
    ctrl = struct();
    for i = 1:numel(ctrl_lines)
        tokens = regexp(ctrl_lines{i}, '([A-Za-z]+d\d+)\s*=\s*([-\d.]+)', 'tokens');
        for j = 1:numel(tokens)
            pair = tokens{j};
            fn   = safe_field(pair{1});
            ctrl.(fn) = str2double(pair{2});
        end
    end
    s.ctrl = ctrl;
end

function val = grep_val(L, pattern)
    val = NaN;
    for i = 1:numel(L)
        tok = regexp(L{i}, pattern, 'tokens');
        if ~isempty(tok), val = str2double(tok{1}{1}); return; end
    end
end

function s = safe_field(s)
    s = regexprep(s, '[^a-zA-Z0-9_]', '_');
    if ~isempty(s) && s(1) >= '0' && s(1) <= '9', s = ['x' s]; end
end

function s = empty_case()
    s = struct('filename','','run_case','','run_num',NaN,'case_num',NaN, ...
        'Sref',NaN,'Cref',NaN,'Bref',NaN,'Xref',NaN, ...
        'alpha',NaN,'beta',NaN,'Mach',NaN,'V',NaN, ...
        'r_rate',NaN,'p_rate',NaN,'q_rate',NaN, ...
        'pb2V',NaN,'qc2V',NaN,'rb2V',NaN, ...
        'CL',NaN,'CD',NaN,'CDind',NaN,'CY',NaN, ...
        'Cl',NaN,'Cm',NaN,'Cn',NaN,'e',NaN, ...
        'CLa',NaN,'CLb',NaN,'CYa',NaN,'CYb',NaN, ...
        'Cla',NaN,'Clb',NaN,'Cma',NaN,'Cmb',NaN, ...
        'Cna',NaN,'Cnb',NaN, ...
        'CLp',NaN,'CLq',NaN,'CLr',NaN, ...
        'CYp',NaN,'CYq',NaN,'CYr',NaN, ...
        'Clp',NaN,'Clq',NaN,'Clr',NaN, ...
        'Cmp',NaN,'Cmq',NaN,'Cmr',NaN, ...
        'Cnp',NaN,'Cnq',NaN,'Cnr',NaN, ...
        'Xnp',NaN,'spiral_stab',NaN,'ctrl',struct());
end

function idx = natural_sort_idx(names)
    padded = cellfun(@(n) regexprep(n, '(\d+)', ...
        '${sprintf(''%06d'', str2double($1))}'), names, 'UniformOutput', false);
    [~, idx] = sort(padded);
end
