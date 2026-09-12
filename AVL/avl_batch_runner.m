% =========================================================
%  AVL Batch Runner — Stability Derivatives (ALL cases)
%  Executes each case individually: select → x → ST → save
% =========================================================

clear; clc;

% ---------------------------------------------------------
% USER SETTINGS
% ---------------------------------------------------------
AVL_EXE   = 'avl.exe';
AVL_FILE  = 'FixedWing.avl';
MASS_FILE = 'FixedWing.mass';
RUN_DIR   = 'avl_run_files';   % folder with run_*.run files
OUT_DIR   = 'V-a-b';           % folder where ST files will be saved

% How many run cases are inside each .run file?
% Open one of your .run files and count the case blocks.
N_CASES = 25;    % <-- set this to match your run files
% ---------------------------------------------------------

if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

runFiles = dir(fullfile(RUN_DIR, 'run_*.run'));
nFiles   = length(runFiles);

if nFiles == 0
    error('No run_*.run files found in: %s', RUN_DIR);
end

fprintf('Found %d run file(s), %d case(s) each.\n\n', nFiles, N_CASES);

% ---------------------------------------------------------
% Main loop
% ---------------------------------------------------------
for i = 1:nFiles

    runFile         = fullfile(RUN_DIR, runFiles(i).name);
    [~, runName, ~] = fileparts(runFiles(i).name);

    fprintf('[%2d/%2d]  %s\n', i, nFiles, runFiles(i).name);

    % Build per-case command block:
    %   {n}   → select case n  (just the number, no prefix)
    %   x     → execute ONLY that case
    %   ST    → stability derivatives output
    %   {file}→ save to file
    % After ST saves, AVL returns to OPER menu automatically.
    % Repeat for next case.

    case_cmds = '';
    stFiles_expected = cell(N_CASES, 1);
    for c = 1:N_CASES
        stFile = fullfile(OUT_DIR, sprintf('%s_case%02d_ST.txt', runName, c));
        stFiles_expected{c} = stFile;
        case_cmds = [case_cmds, sprintf('%d\nx\nST\n%s\n', c, stFile)]; %#ok<AGROW>
    end

    % Full AVL session:
    %   load geometry → load mass → mset 0 → load run file
    %   → oper → [per-case block] → quit
    avlCmds = sprintf([...
        'load %s\n'  ...
        'mass %s\n'  ...
        'mset 0\n'   ...
        'case %s\n'  ...
        'oper\n'     ...
        '%s'         ...   % per-case select/execute/save block
        '\n'         ...   % blank line exits OPER back to top menu
        'quit\n'     ...
        ], AVL_FILE, MASS_FILE, runFile, case_cmds);

    % Write temp input file
    tmpInput = fullfile(RUN_DIR, 'avl_input_tmp.txt');
    fid = fopen(tmpInput, 'w');
    fprintf(fid, '%s', avlCmds);
    fclose(fid);

    % Run AVL
    shellCmd = sprintf('"%s" < "%s"', AVL_EXE, tmpInput);
    [status, cmdout] = system(shellCmd);

    if status ~= 0
        warning('AVL returned non-zero status for %s', runFiles(i).name);
        % Uncomment to see full AVL output for debugging:
        % fprintf('%s\n', cmdout);
    end

    % Check outputs
    n_saved = 0;
    for c = 1:N_CASES
        if exist(stFiles_expected{c}, 'file')
            n_saved = n_saved + 1;
        else
            warning('case %02d NOT saved: %s', c, stFiles_expected{c});
        end
    end
    fprintf('         %d / %d cases saved.\n', n_saved, N_CASES);

end

% Cleanup
if exist(tmpInput, 'file'), delete(tmpInput); end

fprintf('\n========================================\n');
fprintf('Batch complete. Output folder: %s\n', OUT_DIR);
fprintf('========================================\n');

% ---------------------------------------------------------
% OPTIONAL: auto-parse all ST files into one table
% Requires parse_avl_outputs.m in the same folder.
% ---------------------------------------------------------
% stList = dir(fullfile(OUT_DIR, '*_ST.txt'));
% files_to_parse = {stList.name};
% data_dir = OUT_DIR;
% run('parse_avl_outputs.m');
