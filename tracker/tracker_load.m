function [tracker] = tracker_load(identifier, varargin)
% tracker_load Create a new tracker descriptor structure
%
% tracker = tracker_load(identifier, ...)
%
% Create a new tracker structure by searching for a tracker definition file using given
% tracker identifier string.
%
% Input:
% - identifier: A valid tracker identifier string. See `valid_identifier` for more details.
% - varargin[Version]: Version of a tracker. See tracker versioning for more details.
% - varargin[MakeDirectory]: A boolean indicating if a result directory should be automatically generated.
%
% Output:
% - tracker: A new tracker structure.

version = [];
makedirectory = true;

for i = 1:2:length(varargin)
    switch lower(varargin{i})
        case 'version'
            version = varargin{i+1};
        case 'makedirectory'
            makedirectory = varargin{i+1};
        otherwise
            error(['Unknown switch ', varargin{i},'!']) ;
    end
end

if isempty(version)
    tokens = regexp(identifier,':','split');
    if numel(tokens) > 2
        error('Error: %s is not a valid tracker identifier.', identifier);
    elseif numel(tokens) == 2
        family_identifier = tokens{1}; % Override family identifier
        version = tokens{2}; % The second part is the version
    else
        family_identifier = identifier; % By default these are both the same
    end;
else
    family_identifier = identifier;
    identifier = sprintf('%s:%s', identifier, num2str(version));
end;

result_directory = fullfile(get_global_variable('directory'), 'results', identifier);

if makedirectory
    mkpath(result_directory);
end;

[identifier_valid, identifier_conditional] = valid_identifier(family_identifier);
configuration_found = exist(['tracker_' , family_identifier]) ~= 2; %#ok<EXIST>

if ~identifier_conditional
    error('Error: %s is not a valid tracker identifier.', family_identifier);
end;

if configuration_found || ~identifier_valid

	if ~identifier_valid
		print_text('WARNING: Identifier %s contains characters that should not be used.', identifier);
	end

    if ~isempty(version)
        tracker_label = sprintf('%s (%s)', family_identifier, num2str(version));
	else
		tracker_label = family_identifier;
    end;

    print_text('WARNING: No configuration for tracker %s found', identifier);
    tracker = struct('identifier', identifier, 'command', [], ...
        'directory', result_directory, 'linkpath', [], ...
        'label', tracker_label, 'autogenerated', true, 'metadata', struct(), ...
		'interpreter', [], 'version', version, 'trax', true, ...
        'family', family_identifier, 'environment', [], 'parameters', struct());
else

	tracker_metadata = struct();
	tracker_label = [];
	tracker_interpreter = [];
	tracker_linkpath = {};
    tracker_environment = {};
    tracker_parameters = struct();
    tracker_trax = true;

	tracker_configuration = str2func(['tracker_' , family_identifier]);
	tracker_configuration();

    if isempty(tracker_label) || ~ischar(tracker_label)
        if ~isempty(version)
            tracker_label = sprintf('%s (%s)', tracker_label, num2str(version));
        else
            tracker_label = identifier;
        end;
    end;

    if isempty(tracker_interpreter)
        % Additional precaution for Matlab trackers (because they have
        % to be executed differently on Windows and are prettly slow)
        % Detect if a tracker is executed using Matlab
        % and set the interpreter value correctly
        if ispc()
            matlab_executable = fullfile(matlabroot, 'bin', 'matlab.exe');
        else
            matlab_executable = fullfile(matlabroot, 'bin', 'matlab');
        end

        if ~isempty(strfind(lower(tracker_command), lower(matlab_executable)))
            tracker_interpreter = 'matlab';
        end
    end

	tracker = struct('identifier', identifier, 'command', tracker_command, ...
		    'directory', result_directory, 'linkpath', {tracker_linkpath}, ...
		    'label', tracker_label, 'interpreter', tracker_interpreter, ...
		    'autogenerated', false, 'version', version, 'trax', tracker_trax, ...
            'family', family_identifier, 'parameters', tracker_parameters);

    tracker.environment = tracker_environment;

    if ~isascii(tracker.command)
        warning('Tracker command contains non-ASCII characters. This may cause problems.');
    end;

    if ~tracker_test(tracker)
		error('Tracker has not passed the TraX support test.');
	end

	if isstruct(tracker_metadata)
		tracker.metadata = tracker_metadata;
	else
		tracker.metadata = struct();
	end;
end;

performance_filename = fullfile(tracker.directory, 'performance.txt');

if exist(performance_filename, 'file')
    tracker.performance = readstruct(performance_filename);
else
    tracker.performance = [];
end;


