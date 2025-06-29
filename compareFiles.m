%{
    This will compare variable names, comment lines, and  the
    overall structure of the scripts being compared. 
%}

function compareFiles() 

    % opens dialog box that displays the folders in current directory 
    dirPath = uigetdir('');
    
    % check if folder not selected
    if dirPath == 0
        fprintf('No folder was selected.\n');
        return;
    end

    % retrieves all script files only in the directory and stores them in
    % an array. format will be {"file1.m"; "file2.m"; "file3.m";}
    fileList = dir(fullfile(dirPath, '*.m'));
    studentFiles = {fileList.name}';

    % check if folder/selected directory is empty
    if isempty(studentFiles)
        fprintf('No files in the directory were found. \n');
        return;
    end

    % creates matrices size = num of files x num of files
    numFiles = length(studentFiles);
    varCompare = zeros(numFiles, numFiles);
    structCompare = zeros(numFiles, numFiles);
    cmtCompare = zeros(numFiles, numFiles);

    fileTraits = cell(numFiles, 1);

    % extracts from files
    for i = 1:numFiles
        filePath = fullfile(dirPath, studentFiles{i});
        fileTraits{i} = extractCodeFeatures(filePath);
    end

    for i = 1:numFiles
        for j = i+1:numFiles

            % check for variable name similarities in sets
            varCompare(i,j) = jaccardFunc(fileTraits{i}.variables, fileTraits{j}.variables);
            varCompare(j,i) = varCompare(i,j);

            % check for structure similarities
            structCompare(i,j) = 1 - levFunc(fileTraits{i}.structure, fileTraits{j}.structure) / max(length(fileTraits{i}.structure), length(fileTraits{j}.structure));
            structCompare(j,i) = structCompare(i,j);

            % check for comment similarity
            cmtCompare(i,j) = 1 - levFunc(fileTraits{i}.comments, fileTraits{j}.comments) / max(length(fileTraits{i}.comments), length(fileTraits{j}.comments));
            cmtCompare(j,i) = cmtCompare(i,j);
        end
    end
    displayResults(100 * (varCompare), 100 * (cmtCompare), 100 * (structCompare), studentFiles);
end

function features = extractCodeFeatures(filePath)

    features = struct();
    features.variables = {};
    features.comments = '';
    features.structure = '';

    fp = fopen(filePath, 'r');
    if fp == -1
        error('Could not open file: %s\n', filePath);
    end

    % read line by line: newline as delimiter, ignore whitespace
    % stored as array of strings, 1 line = 1 cell
    fileContents = textscan(fp, '%s', 'Delimiter', '\n', 'Whitespace', '');
    fclose(fp);
    % grabs list of lines
    lines = fileContents{1};
    
    % match whitespace, ignore case sensitive
    varPattern = '\s*((?i)[a-z][a-z0-9_]*)\s*=[^=]';
   
    % match control structures + disp()
    structPattern = {'\s*if\s', '\s*for\s', '\s*while\s', '\s*try\s', '\s*catch\s', '\s*switch\s', '\s*case\s', ...
                       '\s*otherwise\s', '\s*break\s', '\s*return\s', '\s*continue\s', '\s*end\s', '\s*parfor\s', '\s*disp\s'};

   for k = 1:length(lines)
       % remove leading whitespace if any
       newline = strtrim(lines{k});

       % skip empty lines 
       if isempty(newline)
           continue;
       end

       % removes leading & trailing whitespace in comments
       if startsWith(newline, '%')
           features.comments = [features.comments, ' ', strtrim(newline(2:end))];
           continue;
       end

       % if % found grabs everything after it and removes leading/trailing
       % whitespace. stores it in features.comments only
       cmtPosition = strfind(newline, '%');
       if ~isempty(cmtPosition)
           features.comments = [features.comments, ' ', strtrim(newline(cmtPosition(1)+1:end))];
           % make sure newline only contains code & removes comment from
           % cell array
           newline = strtrim(newline(1:cmtPosition(1)-1));
       end

       if isempty(newline)
           continue;
       end

       % grab variable names
       varToken = regexp(newline, varPattern, 'tokens');
       if ~isempty(varToken)
           features.variables = [features.variables; varToken{1}];
       end

       % grab code structure, C -> control struct, A -> assignments, O -> other
       if ~isempty(regexp(newline, strjoin(structPattern, '|'), 'once'))
           features.structure = [features.structure 'C']; 
       elseif ~isempty(regexp(newline,'=', 'once'))
           features.structure = [features.structure 'A'];
       else
           features.structure = [features.structure 'O'];
       end
   end

    features.variables = unique(features.variables);
end % end of function features

%{
    Jaccard Similarity is used to measure similarity between sets (in our
    case, variables). It is defined as (A intersect B)/(A union B)
    If the sets are identical = 1, if sets have no common elements = 0
    Some value between 0 and 1 measures their similarity.
%}
function calcSimilarity = jaccardFunc(A, B)

    if isempty(A) && isempty(B)
        calcSimilarity = 1;
        return;
    end
    calcSimilarity = numel(intersect(A,B))/numel(unique([A;B]));
end % end of jaccard similarity function

%{
    This function utilizes Levenshtein distance to measure text similarity
    between the files. Levenshtein distance works by measuring the "edit distance"
    (the distance being the number of subs, deletions, or insertions needed
    to transform one string into the other).
%}
function distSimilarity = levFunc(a,b)
    column = char(a);
    row    = char(b);
    % matrix w/ dimensions length(a)+1 x length(b)+1
    distSimilarity = zeros(length(column)+1, length(row)+1);

      % base case to have starting point
      % fills first column with 0 through length(a)
      for i = 1:length(column)+1
          distSimilarity(i,1) = i-1;
      end
    
      % fills first row with 0 through length(b)
      for j = 1:length(row)+1
          distSimilarity(1,j) = j-1;
      end

    for i = 2:length(column)+1
        for j = 2:length(row)+1

            % comparing characters, -1 because matrix has +1 size
            if column(i-1) == row(j-1) 
                % no substitution
                cost = 0;
            else
                % alteration needed
                cost = 1;
            end
          distSimilarity(i,j) = min([distSimilarity(i-1,j) + 1, ... % cost to delete
              distSimilarity(i,j-1) + 1, ...        % cost to insert
              distSimilarity(i-1,j-1) + cost]);     % cost to sub
        end
    end
    % grab bottom right cell
    distSimilarity = distSimilarity(end,end);
end 

% function to display results
function displayResults(varCompare, structCompare, cmtCompare, studentFiles)
    fprintf('Variable Name Similarities \n');
    disp(array2table(varCompare, 'RowNames', studentFiles, 'VariableNames', studentFiles));

    fprintf('Comment Similarities \n');
    disp(array2table(cmtCompare, 'RowNames', studentFiles, 'VariableNames', studentFiles));

    fprintf('Overall Code Structure Similarities \n');
    disp(array2table(structCompare, 'RowNames', studentFiles, 'VariableNames', studentFiles));
end
   
