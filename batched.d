/*
    This file is part of the Batched distribution.

    https://github.com/senselogic/BATCHED

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    Batched is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Batched is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Batched.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import std.array : replicate;
import std.conv : to;
import std.file : copy, dirEntries, exists, mkdirRecurse, readText, rename, remove, write, FileException, SpanMode;
import std.path : globMatch;
import std.process : execute;
import std.regex : matchFirst, regex, replaceAll, Captures, Regex;
import std.stdio : writeln;
import std.string : endsWith, indexOf, join, lastIndexOf, replace, split, startsWith, strip, stripLeft, stripRight, toLower, toUpper;

// -- TYPES

class FILE_INTERVAL
{
    // -- ATTRIBUTES

    long
        LineIndex,
        PostLineIndex;
    string
        Indentation;
}

// ~~

class FILE_SELECTION
{
    // -- ATTRIBUTES

    bool
        ItIsSelected;
}


// ~~

class FILE_MARK
{
    // -- ATTRIBUTES

    bool
        ItIsMarked;
}

// ~~

class FILE
{
    // -- ATTRIBUTES

    string
        InputPath,
        InputFolderPath,
        InputName,
        InputSubFolderPath,
        InputBaseName,
        InputExtension,
        InputBaseExtension,
        OutputPath,
        OutputFolderPath,
        OutputName,
        OutputSubFolderPath,
        OutputBaseName,
        OutputExtension,
        OutputBaseExtension;
    string[]
        LineArray;
    bool[]
        LineHasChangedArray;
    long
        LineIndex,
        PostLineIndex;
    bool
        ItIsSelected,
        ItIsMarked;
    string
        Indentation;
    string[ string ]
        VariableMap;
    FILE_INTERVAL[]
        IntervalArray;
    FILE_SELECTION[]
        SelectionArray;
    FILE_MARK[]
        MarkArray;

    // -- INQUIRIES

    bool HasLineInterval(
        )
    {
        return
           LineIndex < LineArray.length.to!long()
           && LineIndex < PostLineIndex;
    }

    // ~~

    bool IsSelected(
        )
    {
        return
            ( ( Script.FilesMustBeSelected
                && ItIsSelected )
              || ( Script.FilesMustNotBeSelected
                   && !ItIsSelected )
              || ( !Script.FilesMustBeSelected
                   && !Script.FilesMustNotBeSelected ) )
            && ( ( Script.FilesMustBeMarked
                   && ItIsMarked )
                 || ( Script.FilesMustNotBeMarked
                      && !ItIsMarked )
                 || ( !Script.FilesMustBeMarked
                        && !Script.FilesMustNotBeMarked ) )
            && ( ( Script.FilesMustHaveLineInterval
                   && HasLineInterval() )
                 || !Script.FilesMustHaveLineInterval );
    }

    // ~~

    long GetValidLineIndex(
        long line_index
        )
    {
        if ( line_index < 0
             || line_index > LineArray.length )
        {
            Abort( "Invalid line index : " ~ line_index.to!string() );
        }

        return line_index;
    }

    // ~~

    long GetLineIndex(
        string line_index_expression
        )
    {
        if ( line_index_expression == "[" )
        {
            return GetValidLineIndex( LineIndex );
        }
        else if ( line_index_expression.startsWith( "[-" ) )
        {
            return GetValidLineIndex( LineIndex - Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else if ( line_index_expression.startsWith( "[+" ) )
        {
            return GetValidLineIndex( LineIndex + Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else if ( line_index_expression == "]" )
        {
            return GetValidLineIndex( PostLineIndex );
        }
        else if ( line_index_expression.startsWith( "]-" ) )
        {
            return GetValidLineIndex( PostLineIndex - Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else if ( line_index_expression.startsWith( "]+" ) )
        {
            return GetValidLineIndex( PostLineIndex + Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else if ( line_index_expression == "$" )
        {
            return GetValidLineIndex( LineArray.length.to!long() );
        }
        else if ( line_index_expression.startsWith( "$-" ) )
        {
            return GetValidLineIndex( LineArray.length.to!long() - Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else if ( line_index_expression.startsWith( "$+" ) )
        {
            return GetValidLineIndex( LineArray.length.to!long() + Script.GetValue( line_index_expression[ 2 .. $ ], this ).GetInteger() );
        }
        else
        {
            return GetValidLineIndex( Script.GetValue( line_index_expression, this ).GetInteger() );
        }
    }

    // ~~

    long GetLineIndex(
        string line_index_expression,
        long minimum_line_index
        )
    {
        long
            line_index;

        line_index = GetLineIndex( line_index_expression );

        if ( line_index < minimum_line_index )
        {
            return minimum_line_index;
        }
        else
        {
            return line_index;
        }
    }

    // ~~

    bool MatchesFilter(
        string file_path_filter
        )
    {
        string
            file_name_filter,
            folder_path;
        SpanMode
            span_mode;

        SplitFilePathFilter( file_path_filter, folder_path, file_name_filter, span_mode );

        return
            ( InputFolderPath == folder_path
              || ( span_mode == SpanMode.depth
                   && InputFolderPath.startsWith( folder_path ) ) )
            && InputName.globMatch( file_name_filter );
    }

    // -- OPERATIONS

    void Abort(
        string message
        )
    {
        writeln( "*** ERROR : ", message, " (", InputPath, " => ", OutputPath, ")" );

        exit( -1 );
    }

    // ~~

    void ClearIndentation(
        )
    {
        Indentation = "";
    }

    // ~~

    void SetIndentation(
        )
    {
        Indentation = "";

        if ( LineIndex < LineArray.length )
        {
            foreach ( character; LineArray[ LineIndex ] )
            {
                if ( character == '\t' )
                {
                    Indentation ~= '\t';
                }
                else if ( character == ' ' )
                {
                    Indentation ~= ' ';
                }
                else
                {
                    break;
                }
            }
        }
    }

    // ~~

    void Select(
        )
    {
        if ( Script.FilesAreSelected )
        {
            ItIsSelected = true;
        }

        SetIndentation();
    }

    // ~~

    void Ignore(
        )
    {
        if ( Script.FilesAreSelected )
        {
            ItIsSelected = false;
        }

        ClearIndentation();
    }

    // ~~

    void Mark(
        )
    {
        if ( Script.FilesAreMarked )
        {
            ItIsMarked = true;
        }
    }

    // ~~

    void Unmark(
        )
    {
        if ( Script.FilesAreMarked )
        {
            ItIsMarked = false;
        }
    }

    // ~~

    void ReadFile(
        string input_file_path,
        string output_file_path
        )
    {
        string
            file_text;

        if ( input_file_path.exists() )
        {
            SetInputPath( input_file_path );
            SetOutputPath( output_file_path );

            writeln( "Reading file : ", InputPath );

            try
            {
                file_text = input_file_path.readText().replace( "\r", "" );
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't read file : " ~ InputPath );
            }

            LineArray = file_text.Split();
            LineIndex = 0;
            PostLineIndex = LineArray.length;
            LineHasChangedArray.length = LineArray.length;
        }
        else
        {
            Abort( "Can't read file : " ~ InputPath );
        }
    }

    // ~~

    void CreateFile(
        string input_file_path,
        string output_file_path
        )
    {
        SetInputPath( input_file_path );
        SetOutputPath( output_file_path );
    }

    // ~~

    void SetInputPath(
        string input_file_path
        )
    {
        InputPath = input_file_path;

        SplitFilePath( InputPath, InputFolderPath, InputName );
        SplitFileName( InputName, InputBaseName, InputExtension );

        InputBaseExtension = InputExtension.replace( ".", "" );

        if ( InputFolderPath.startsWith( Script.InputFolderPath ) )
        {
            InputSubFolderPath = InputFolderPath[ Script.InputFolderPath.length .. $ ];
        }
        else
        {
            InputSubFolderPath = "";
        }

        VariableMap[ "InputPath" ] = InputPath;
        VariableMap[ "InputFolder" ] = InputFolderPath;
        VariableMap[ "InputSubFolder" ] = InputSubFolderPath;
        VariableMap[ "InputName" ] = InputName;
        VariableMap[ "InputBaseName" ] = InputBaseName;
        VariableMap[ "InputExtension" ] = InputExtension;
        VariableMap[ "InputBaseExtension" ] = InputBaseExtension;
    }

    // ~~

    void SetOutputPath(
        string output_file_path
        )
    {
        OutputPath = output_file_path;

        SplitFilePath( OutputPath, OutputFolderPath, OutputName );
        SplitFileName( OutputName, OutputBaseName, OutputExtension );

        OutputBaseExtension = OutputExtension.replace( ".", "" );

        if ( OutputFolderPath.startsWith( Script.OutputFolderPath ) )
        {
            OutputSubFolderPath = OutputFolderPath[ Script.OutputFolderPath.length .. $ ];
        }
        else
        {
            OutputSubFolderPath = "";
        }

        VariableMap[ "OutputPath" ] = OutputPath;
        VariableMap[ "OutputFolder" ] = OutputFolderPath;
        VariableMap[ "OutputSubFolder" ] = OutputSubFolderPath;
        VariableMap[ "OutputName" ] = OutputName;
        VariableMap[ "OutputBaseName" ] = OutputBaseName;
        VariableMap[ "OutputExtension" ] = OutputExtension;
        VariableMap[ "OutputBaseExtension" ] = OutputBaseExtension;
    }

    // ~~

    void CreateFolder(
        )
    {
        Script.CreateFolder( OutputFolderPath );
    }

    // ~~

    void WriteFile(
        )
    {
        string
            file_text;

        file_text = LineArray.Join();

        writeln( "Writing file : ", OutputPath );

        if ( !PreviewOptionIsEnabled )
        {
            try
            {
                OutputPath.write( file_text );
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't write file : " ~ OutputPath );
            }
        }
    }

    // ~~

    void PrintFilePath(
        )
    {
        writeln(
            InputPath,
            " ",
            ItIsSelected ? "^" : "",
            ItIsMarked ? "?" : "",
            "(",
            LineIndex,
            "-",
            PostLineIndex,
            ">",
            Indentation.length,
            ") :"
            );
    }

    // ~~

    void PrintRanges(
        )
    {
        writeln(
            InputPath,
            " ",
            ItIsSelected ? "^" : "",
            ItIsMarked ? "+" : "",
            "(",
            LineIndex,
            "+",
            PostLineIndex - LineIndex,
            ">",
            Indentation.length,
            ")"
            );
    }

    // ~~

    void PrintIntervals(
        )
    {
        writeln(
            InputPath,
            " ",
            ItIsSelected ? "^" : "",
            ItIsMarked ? "?" : "",
            "(",
            LineIndex,
            "-",
            PostLineIndex,
            ">",
            Indentation.length,
            ")"
            );
    }

    // ~~

    void PrintLines(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        long
            first_line_index,
            line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        PrintFilePath();

        for ( line_index = line_index;
              line_index < post_line_index;
              ++line_index )
        {
            writeln( "    [", line_index, "] ", LineArray[ line_index ] );
        }
    }

    // ~~

    void PrintSelectedLines(
        )
    {
        long
            line_index;

        PrintFilePath();

        for ( line_index = LineIndex;
              line_index < PostLineIndex;
              ++line_index )
        {
            writeln( "    [", line_index, "] ", LineArray[ line_index ] );
        }
    }

    // ~~

    void PrintChangedLines(
        long dump_line_count
        )
    {
        bool
            line_has_changed;
        long
            changed_line_index,
            line_offset;

        PrintFilePath();

        foreach ( line_index, ref line; LineArray )
        {
            line_has_changed = false;

            for ( line_offset = -dump_line_count;
                  line_offset <= dump_line_count;
                  ++line_offset )
            {
                changed_line_index = line_index + line_offset;

                if ( changed_line_index >= 0
                     && changed_line_index < LineArray.length
                     && LineHasChangedArray[ changed_line_index ] )
                {
                    line_has_changed = true;
                }
            }

            if ( line_has_changed )
            {
                if ( LineHasChangedArray[ line_index ] )
                {
                    writeln( "    *", line_index, "* ", line );
                }
                else
                {
                    writeln( "    [", line_index, "] ", line );
                }
            }
        }
    }

    // ~~

    void SetLineAtIndex(
        string line,
        long line_index
        )
    {
        if ( LineArray[ line_index ] != line )
        {
            LineArray[ line_index ] = line;
            LineHasChangedArray[ line_index ] = true;
        }
    }

    // ~~

    void FixInterval(
        )
    {
        if ( LineIndex < 0 )
        {
            LineIndex = 0;
        }

        if ( LineIndex > LineArray.length )
        {
            LineIndex = LineArray.length;
        }

        if ( PostLineIndex < LineIndex )
        {
            PostLineIndex = LineIndex;
        }

        if ( PostLineIndex > LineArray.length )
        {
            PostLineIndex = LineArray.length;
        }
    }

    // ~~

    void IncreaseInterval(
        long line_index,
        long post_line_index
        )
    {
        long
            line_count;

        line_count = post_line_index - line_index;

        while ( line_count > 0 )
        {
            if ( line_index >= LineIndex
                 && line_index < PostLineIndex )
            {
                ++PostLineIndex;
            }

            if ( line_index < LineIndex )
            {
                ++LineIndex;
                ++PostLineIndex;
            }

            --line_count;
        }

        FixInterval();
    }

    // ~~

    void DecreaseInterval(
        long line_index,
        long post_line_index
        )
    {
        long
            line_count;

        line_count = post_line_index - line_index;

        while ( line_count > 0 )
        {
            if ( line_index >= LineIndex
                 && line_index < PostLineIndex )
            {
                --PostLineIndex;
            }

            if ( line_index < LineIndex )
            {
                --LineIndex;
                --PostLineIndex;
            }

            --line_count;
        }

        FixInterval();
    }

    // ~~

    void SetLineIndex(
        string line_index_expression
        )
    {
        LineIndex = GetLineIndex( line_index_expression );

        FixInterval();
    }

    // ~~

    void SetLineCount(
        long line_count
        )
    {
        PostLineIndex = LineIndex + line_count;

        FixInterval();
    }

    // ~~

    void SetLineRange(
        string line_index_expression,
        long line_count
        )
    {
        LineIndex = GetLineIndex( line_index_expression );
        PostLineIndex = LineIndex + line_count;

        FixInterval();
    }

    // ~~

    void SetPostLineIndex(
        string post_line_index_expression
        )
    {
        PostLineIndex = GetLineIndex( post_line_index_expression );

        FixInterval();
    }

    // ~~

    void SetLineInterval(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        long
            line_index,
            post_line_index;

        line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, line_index );

        LineIndex = line_index;
        PostLineIndex = post_line_index;

        FixInterval();
    }

    // ~~

    void ReplaceTabulations(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        foreach ( line_index; first_line_index .. post_line_index )
        {
            SetLineAtIndex( LineArray[ line_index ].ReplaceTabulations( Script.TabulationSpaceCount ), line_index );
        }
    }

    // ~~

    void ReplaceSpaces(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        long
            first_line_index,
            post_line_index;
        string
            tabulation_text;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        tabulation_text = "        "[ 0 .. Script.TabulationSpaceCount ];

        foreach ( line_index; first_line_index .. post_line_index )
        {
            SetLineAtIndex( LineArray[ line_index ].ReplaceSpaces( Script.TabulationSpaceCount ), line_index );
        }
    }

    // ~~

    void ReplaceText(
        string line_index_expression,
        string post_line_index_expression,
        string old_text,
        string new_text,
        bool it_must_be_unquoted,
        bool it_must_be_quoted,
        bool it_must_be_in_identifier
        )
    {
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        foreach ( line_index; first_line_index .. post_line_index )
        {
            SetLineAtIndex(
                LineArray[ line_index ].ReplaceText( old_text, new_text, it_must_be_unquoted, it_must_be_quoted, it_must_be_in_identifier ),
                line_index
                );
        }
    }

    // ~~

    void ReplaceExpression(
        string line_index_expression,
        string post_line_index_expression,
        ref Regex!char old_expression,
        string new_text
        )
    {
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        foreach ( line_index; first_line_index .. post_line_index )
        {
            SetLineAtIndex( LineArray[ line_index ].replaceAll( old_expression, new_text ), line_index );
        }
    }

    // ~~

    void FindText(
        string line_index_expression,
        string post_line_index_expression,
        string text
        )
    {
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        LineIndex = first_line_index;
        PostLineIndex = post_line_index;

        while ( LineIndex < LineArray.length )
        {
            if ( Script.Strip( LineArray[ LineIndex ] ).indexOf( text ) >= 0 )
            {
                Select();

                PostLineIndex = LineIndex + 1;

                return;
            }

            ++LineIndex;
        }

        Ignore();

        LineIndex = PostLineIndex;

        if ( !Script.FilesAreSelected )
        {
            Abort( "Text not found : " ~ text );
        }
    }

    // ~~

    void ReachText(
        string post_line_index_expression,
        string text
        )
    {
        long
            post_line_index;

        post_line_index = GetLineIndex( post_line_index_expression, LineIndex );

        while ( PostLineIndex < post_line_index )
        {
            if ( Script.Strip( LineArray[ PostLineIndex ] ).indexOf( text ) >= 0 )
            {
                Select();

                ++PostLineIndex;

                return;
            }

            ++PostLineIndex;
        }

        Ignore();

        if ( !Script.FilesAreSelected )
        {
            Abort( "Text not reached : " ~ text );
        }
    }

    // ~~

    void FindLines(
        string line_index_expression,
        string post_line_index_expression,
        string[] line_array
        )
    {
        bool
            lines_match;
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        LineIndex = first_line_index;
        PostLineIndex = post_line_index;

        while ( LineIndex + line_array.length.to!long() - 1
                < LineArray.length.to!long() )
        {
            lines_match = true;

            foreach ( line_index; 0 .. line_array.length )
            {
                if ( Script.Strip( LineArray[ LineIndex + line_index ] ) != line_array[ line_index ] )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex = LineIndex + line_array.length;

                return;
            }

            ++LineIndex;
        }

        Ignore();

        LineIndex = PostLineIndex;

        if ( !Script.FilesAreSelected )
        {
            Abort( "Lines not found" );
        }
    }

    // ~~

    void ReachLines(
        string post_line_index_expression,
        string[] line_array
        )
    {
        bool
            lines_match;
        long
            post_line_index;

        post_line_index = GetLineIndex( post_line_index_expression, LineIndex );

        while ( PostLineIndex + line_array.length.to!long() - 1
                < post_line_index )
        {
            lines_match = true;

            foreach ( line_index; 0 .. line_array.length )
            {
                if ( Script.Strip( LineArray[ PostLineIndex + line_index ] ) != line_array[ line_index ] )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex += line_array.length;

                return;
            }

            ++PostLineIndex;
        }

        Ignore();

        if ( !Script.FilesAreSelected )
        {
            Abort( "Lines not reached" );
        }
    }

    // ~~

    void FindPrefixes(
        string line_index_expression,
        string post_line_index_expression,
        string[] prefix_array
        )
    {
        bool
            lines_match;
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        LineIndex = first_line_index;
        PostLineIndex = post_line_index;

        while ( LineIndex + prefix_array.length.to!long() - 1
                < LineArray.length.to!long() )
        {
            lines_match = true;

            foreach ( prefix_index; 0 .. prefix_array.length )
            {
                if ( !Script.Strip( LineArray[ LineIndex + prefix_index ] ).startsWith( prefix_array[ prefix_index ] ) )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex = LineIndex + prefix_array.length;

                return;
            }

            ++LineIndex;
        }

        Ignore();

        LineIndex = PostLineIndex;

        if ( !Script.FilesAreSelected )
        {
            Abort( "Prefixes not found" );
        }
    }

    // ~~

    void ReachPrefixes(
        string post_line_index_expression,
        string[] prefix_array
        )
    {
        bool
            lines_match;
        long
            post_line_index;

        post_line_index = GetLineIndex( post_line_index_expression, LineIndex );

        while ( PostLineIndex + prefix_array.length.to!long() - 1
                < post_line_index )
        {
            lines_match = true;

            foreach ( prefix_index; 0 .. prefix_array.length )
            {
                if ( !Script.Strip( LineArray[ PostLineIndex + prefix_index ] ).startsWith( prefix_array[ prefix_index ] ) )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex += prefix_array.length;

                return;
            }

            ++PostLineIndex;
        }

        Ignore();

        if ( !Script.FilesAreSelected )
        {
            Abort( "Prefixes not reached" );
        }
    }

    // ~~

    void FindSuffixes(
        string line_index_expression,
        string post_line_index_expression,
        string[] suffix_array
        )
    {
        bool
            lines_match;
        long
            first_line_index,
            post_line_index;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        LineIndex = first_line_index;
        PostLineIndex = post_line_index;

        while ( LineIndex + suffix_array.length.to!long() - 1
                < LineArray.length.to!long() )
        {
            lines_match = true;

            foreach ( suffix_index; 0 .. suffix_array.length )
            {
                if ( !Script.Strip( LineArray[ LineIndex + suffix_index ] ).endsWith( suffix_array[ suffix_index ] ) )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex = LineIndex + suffix_array.length;

                return;
            }

            ++LineIndex;
        }

        Ignore();

        LineIndex = PostLineIndex;

        if ( !Script.FilesAreSelected )
        {
            Abort( "Suffixes not found" );
        }
    }

    // ~~

    void ReachSuffixes(
        string post_line_index_expression,
        string[] suffix_array
        )
    {
        bool
            lines_match;
        long
            post_line_index;

        post_line_index = GetLineIndex( post_line_index_expression, LineIndex );

        while ( PostLineIndex + suffix_array.length.to!long() - 1
                < post_line_index )
        {
            lines_match = true;

            foreach ( suffix_index; 0 .. suffix_array.length )
            {
                if ( !Script.Strip( LineArray[ PostLineIndex + suffix_index ] ).endsWith( suffix_array[ suffix_index ] ) )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex += suffix_array.length;

                return;
            }

            ++PostLineIndex;
        }

        Ignore();

        if ( !Script.FilesAreSelected )
        {
            Abort( "Suffixes not reached" );
        }
    }

    // ~~

    void FindExpressions(
        string line_index_expression,
        string post_line_index_expression,
        ref Regex!char[] expression_array
        )
    {
        bool
            lines_match;
        long
            expression_index,
            first_line_index,
            post_line_index;
        Captures!( string )
            match;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        LineIndex = first_line_index;
        PostLineIndex = post_line_index;

        while ( LineIndex + expression_array.length.to!long() - 1
                < LineArray.length.to!long() )
        {
            lines_match = true;

            for ( expression_index = 0;
                  expression_index < expression_array.length;
                  ++expression_index )
            {
                match = Script.Strip( LineArray[ LineIndex + expression_index ] ).matchFirst( expression_array[ expression_index ] );

                if ( match.empty() )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex = LineIndex + expression_array.length;

                return;
            }

            ++LineIndex;
        }

        Ignore();

        LineIndex = PostLineIndex;

        if ( !Script.FilesAreSelected )
        {
            Abort( "Expressions not found" );
        }
    }

    // ~~

    void ReachExpressions(
        string post_line_index_expression,
        ref Regex!char[] expression_array
        )
    {
        bool
            lines_match;
        long
            expression_index,
            post_line_index;
        Captures!( string )
            match;

        post_line_index = GetLineIndex( post_line_index_expression, LineIndex );

        while ( PostLineIndex + expression_array.length.to!long() - 1
                < post_line_index )
        {
            lines_match = true;

            for ( expression_index = 0;
                  expression_index < expression_array.length;
                  ++expression_index )
            {
                match = Script.Strip( LineArray[ PostLineIndex + expression_index ] ).matchFirst( expression_array[ expression_index ] );

                if ( match.empty() )
                {
                    lines_match = false;

                    break;
                }
            }

            if ( lines_match )
            {
                Select();

                PostLineIndex += expression_array.length;

                return;
            }

            ++PostLineIndex;
        }

        Ignore();

        if ( !Script.FilesAreSelected )
        {
            Abort( "Expressions not reached" );
        }
    }

    // ~~

    void InsertLines(
        string line_index_expression,
        string character_index_expression,
        string[] line_array
        )
    {
        long
            character_index,
            first_line_index,
            post_line_index;
        string
            line;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = first_line_index + line_array.length;

        foreach ( line_index; first_line_index .. post_line_index )
        {
            if ( line_index < LineArray.length )
            {
                line = LineArray[ line_index ];

                character_index = Script.GetCharacterIndex( line, character_index_expression, this );

                SetLineAtIndex(
                    line[ 0 .. character_index ]
                    ~ line_array[ line_index - first_line_index ]
                    ~ line[ character_index .. $ ],
                    line_index
                    );
            }
            else
            {
                Abort( "Invalid line index" );
            }
        }
    }

    // ~~

    void AddLines(
        string line_index_expression,
        string[] line_array
        )
    {
        bool[]
            line_has_changed_array;
        long
            line_index,
            post_line_index;

        line_index = GetLineIndex( line_index_expression );
        post_line_index = line_index + line_array.length;

        line_has_changed_array.length = line_array.length;

        foreach ( ref changed; line_has_changed_array )
        {
            changed = true;
        }

        LineArray = LineArray[ 0 .. line_index ] ~ line_array ~ LineArray[ line_index .. $ ];
        LineHasChangedArray = LineHasChangedArray[ 0 .. line_index ] ~ line_has_changed_array ~ LineHasChangedArray[ line_index .. $ ];

        IncreaseInterval( line_index, post_line_index );
    }

    // ~~

    void AddEmptyLines(
        string line_index_expression,
        long line_count
        )
    {
        string[]
            line_array;

        line_array.length = line_count;

        AddLines( line_index_expression, line_array );
    }

    // ~~

    void RemoveLines(
        long line_index,
        long post_line_index
        )
    {
        LineArray = LineArray[ 0 .. line_index ] ~ LineArray[ post_line_index .. $ ];
        LineHasChangedArray = LineHasChangedArray[ 0 .. line_index ] ~ LineHasChangedArray[ post_line_index .. $ ];

        DecreaseInterval( line_index, post_line_index );
    }

    // ~~

    void RemoveLines(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        long
            line_index,
            post_line_index;

        line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, line_index );

        RemoveLines( line_index, post_line_index );
    }

    // ~~

    void RemoveFirstEmptyLines(
        string line_index_expression,
        string post_line_index_expression,
        long line_count
        )
    {
        long
            first_line_index,
            line_index,
            post_line_index,
            removed_line_count;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        removed_line_count = 0;

        for ( line_index = first_line_index;
              line_index < post_line_index
              && ( line_count < 0
                   || removed_line_count < line_count );
              ++line_index )
        {
            if ( LineArray[ line_index ].strip().length == 0 )
            {
                ++removed_line_count;
            }
            else
            {
                break;
            }
        }

        if ( removed_line_count > 0 )
        {
            RemoveLines( first_line_index, first_line_index + removed_line_count );
        }
    }

    // ~~

    void RemoveLastEmptyLines(
        string line_index_expression,
        string post_line_index_expression,
        long line_count
        )
    {
        long
            first_line_index,
            line_index,
            post_line_index,
            removed_line_count;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        removed_line_count = 0;

        for ( line_index = post_line_index - 1;
              line_index >= first_line_index
              && ( line_count < 0
                   || removed_line_count < line_count );
              --line_index )
        {
            if ( LineArray[ line_index ].strip().length == 0 )
            {
                ++removed_line_count;
            }
            else
            {
                break;
            }
        }

        if ( removed_line_count > 0 )
        {
            RemoveLines( post_line_index - removed_line_count, post_line_index );
        }
    }

    // ~~

    void RemoveEmptyLines(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        bool[]
            line_has_changed_array;
        long
            first_line_index,
            line_index,
            post_line_index;
        string[]
            line_array;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        line_array = null;
        line_has_changed_array = null;

        for ( line_index = first_line_index;
              line_index < post_line_index;
              ++line_index )
        {
            if ( LineArray[ line_index ].strip().length > 0 )
            {
                line_array ~= LineArray[ line_index ];
                line_has_changed_array ~= LineHasChangedArray[ line_index ];
            }
            else
            {
                DecreaseInterval( line_index, 1 );
            }
        }

        LineArray = LineArray[ 0 .. first_line_index ] ~ line_array ~ LineArray[ post_line_index .. $ ];
        LineHasChangedArray = LineHasChangedArray[ 0 .. first_line_index ] ~ line_has_changed_array ~ LineHasChangedArray[ post_line_index .. $ ];
    }

    // ~~

    void RemoveDoubleEmptyLines(
        string line_index_expression,
        string post_line_index_expression
        )
    {
        bool[]
            line_has_changed_array;
        long
            first_line_index,
            line_index,
            post_line_index;
        string[]
            line_array;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        line_array = null;
        line_has_changed_array = null;

        for ( line_index = first_line_index;
              line_index < post_line_index;
              ++line_index )
        {
            if ( LineArray[ line_index ].strip().length > 0
                 || line_index + 1 >= LineArray.length
                 || LineArray[ line_index + 1 ].strip().length > 0 )
            {
                line_array ~= LineArray[ line_index ];
                line_has_changed_array ~= LineHasChangedArray[ line_index ];
            }
            else
            {
                DecreaseInterval( line_index, 1 );
            }
        }

        LineArray = LineArray[ 0 .. first_line_index ] ~ line_array ~ LineArray[ post_line_index .. $ ];
        LineHasChangedArray = LineHasChangedArray[ 0 .. first_line_index ] ~ line_has_changed_array ~ LineHasChangedArray[ post_line_index .. $ ];
    }

    // ~~

    void SkipLines(
        )
    {
        LineIndex = PostLineIndex;
    }

    // ~~

    void SetLines(
        string line_index_expression,
        string post_line_index_expression,
        string[] line_array
        )
    {
        RemoveLines( line_index_expression, post_line_index_expression );

        AddLines( line_index_expression, line_array );
    }

    // ~~

    void CopyLines(
        string variable_name,
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        string post_character_index_expression
        )
    {
        long
            character_index,
            first_line_index,
            post_character_index,
            post_line_index;
        string
            line;
        string[]
            clipped_line_array;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        if ( character_index_expression.length == 0 )
        {
            Script.SetVariable(
                variable_name,
                LineArray[ first_line_index .. post_line_index ].Join(),
                this
                );
        }
        else
        {
            clipped_line_array.length = post_line_index - first_line_index;

            foreach ( line_index; first_line_index .. post_line_index )
            {
                line = LineArray[ line_index ];

                character_index = Script.GetCharacterIndex( line, character_index_expression, this );
                post_character_index = Script.GetCharacterIndex( line, post_character_index_expression, this );

                clipped_line_array[ line_index - first_line_index ] = line[ character_index .. post_character_index ];
            }

            Script.SetVariable(
                variable_name,
                clipped_line_array.Join(),
                this
                );
        }
    }

    // ~~

    void CutLines(
        string variable_name,
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        string post_character_index_expression
        )
    {
        CopyLines( variable_name, line_index_expression, post_line_index_expression, character_index_expression, post_character_index_expression );

        if ( character_index_expression.length == 0 )
        {
            RemoveText( line_index_expression, post_line_index_expression, character_index_expression, post_character_index_expression );
        }
        else
        {
            RemoveLines( line_index_expression, post_line_index_expression );
        }
    }

    // ~~

    void PasteLines(
        string variable_name,
        string line_index_expression,
        string character_index_expression
        )
    {
        string[]
            variable_line_array;

        variable_line_array = Script.GetVariable( variable_name, this ).Split();

        if ( character_index_expression.length == 0 )
        {
            AddLines( line_index_expression, variable_line_array );
        }
        else
        {
            InsertLines( line_index_expression, character_index_expression, variable_line_array );
        }
    }

    // ~~

    void AddText(
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        string text
        )
    {
        long
            character_index,
            line_index;
        string
            line;

        for ( line_index = LineIndex;
              line_index < PostLineIndex;
              ++line_index )
        {
            line = LineArray[ line_index ];
            character_index = Script.GetCharacterIndex( line, character_index_expression, this );

            SetLineAtIndex( line[ 0 .. character_index ] ~ text ~ line[ character_index .. $ ], line_index );
        }
    }

    // ~~

    void RemovePrefix(
        string line_index_expression,
        string post_line_index_expression,
        string prefix
        )
    {
        long
            line_index;
        string
            line;

        for ( line_index = LineIndex;
              line_index < PostLineIndex;
              ++line_index )
        {
            line = LineArray[ line_index ];

            if ( line.startsWith( prefix ) )
            {
                SetLineAtIndex( line[ prefix.length .. $ ], line_index );
            }
        }
    }

    // ~~

    void RemoveSuffix(
        string line_index_expression,
        string post_line_index_expression,
        string suffix
        )
    {
        long
            line_index;
        string
            line;

        for ( line_index = LineIndex;
              line_index < PostLineIndex;
              ++line_index )
        {
            line = LineArray[ line_index ];

            if ( line.endsWith( suffix ) )
            {
                SetLineAtIndex( line[ 0 .. $ - suffix.length ], line_index );
            }
        }
    }

    // ~~

    void RemoveSideText(
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        string post_character_index_expression
        )
    {
        long
            character_index,
            first_line_index,
            post_character_index,
            post_line_index;
        string
            line;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        foreach ( line_index; first_line_index .. post_line_index )
        {
            line = LineArray[ line_index ];

            character_index = Script.GetCharacterIndex( line, character_index_expression, this );
            post_character_index = Script.GetCharacterIndex( line, post_character_index_expression, this );

            SetLineAtIndex(
                line[ character_index .. post_character_index ],
                line_index
                );
        }
    }

    // ~~

    void RemoveText(
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        string post_character_index_expression
        )
    {
        long
            character_index,
            first_line_index,
            post_character_index,
            post_line_index;
        string
            line;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        foreach ( line_index; first_line_index .. post_line_index )
        {
            line = LineArray[ line_index ];

            character_index = Script.GetCharacterIndex( line, character_index_expression, this );
            post_character_index = Script.GetCharacterIndex( line, post_character_index_expression, this );

            SetLineAtIndex(
                line[ 0 .. character_index ] ~ line[ post_character_index .. $ ],
                line_index
                );
        }
    }

    // ~~

    void AddSpaces(
        string line_index_expression,
        string post_line_index_expression,
        string character_index_expression,
        long space_count
        )
    {
        AddText(
            line_index_expression,
            post_line_index_expression,
            character_index_expression,
            " ".replicate( space_count )
            );
    }

    // ~~

    void RemoveFirstSpaces(
        string line_index_expression,
        string post_line_index_expression,
        long space_count
        )
    {
        char
            character;
        long
            character_index,
            first_line_index,
            post_line_index,
            removed_space_count;
        string
            line;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        if ( post_line_index > first_line_index )
        {
            foreach ( line_index; first_line_index .. post_line_index )
            {
                line = LineArray[ line_index ];

                if ( line.length > 0 )
                {
                    removed_space_count = 0;

                    for ( character_index = 0;
                          character_index < line.length
                          && ( space_count < 0
                               || removed_space_count < space_count );
                          ++character_index )
                    {
                        character = line[ character_index ];

                        if ( character == ' ' )
                        {
                            ++removed_space_count;
                        }
                        else if ( character == '\t' )
                        {
                            removed_space_count += Script.TabulationSpaceCount;
                        }
                        else
                        {
                            break;
                        }
                    }

                    SetLineAtIndex( line[ character_index .. $ ], line_index );
                }
            }
        }
    }

    // ~~

    void RemoveLastSpaces(
        string line_index_expression,
        string post_line_index_expression,
        long space_count
        )
    {
        char
            character;
        long
            character_index,
            first_line_index,
            post_line_index,
            removed_space_count;
        string
            line;

        first_line_index = GetLineIndex( line_index_expression );
        post_line_index = GetLineIndex( post_line_index_expression, first_line_index );

        if ( post_line_index > first_line_index )
        {
            foreach ( line_index; first_line_index .. post_line_index )
            {
                line = LineArray[ line_index ];

                if ( line.length > 0 )
                {
                    removed_space_count = 0;

                    for ( character_index = line.length.to!long() - 1;
                          character_index >= 0
                          && ( space_count < 0
                               || removed_space_count < space_count );
                          --character_index )
                    {
                        character = line[ character_index ];

                        if ( character == ' ' )
                        {
                            ++removed_space_count;
                        }
                        else if ( character == '\t' )
                        {
                            removed_space_count += Script.TabulationSpaceCount;
                        }
                        else
                        {
                            break;
                        }
                    }

                    SetLineAtIndex( line[ 0 .. character_index + 1 ], line_index );
                }
            }
        }
    }
}

// ~~

class CALL
{
    // -- ATTRIBUTES

    string[]
        ArgumentArray;
    long
        ReturnLineIndex;
}

// ~~

class SCRIPT
{
    // -- ATTRIBUTES

    string
        FilePath;
    string[]
        ArgumentArray;
    string[ string ]
        VariableMap;
    CALL[]
        CallArray;
    string
        Result;
    bool
        QuotationIsEnabled,
        FirstSpacesAreChecked,
        LastSpacesAreChecked,
        InnerSpacesAreChecked;
    long
        TabulationSpaceCount;
    long
        LineIndex;
    string[]
        LineArray;
    long[]
        LineIndexArray;
    string[]
        FilePathArray;
    string
        InputFolderPath,
        OutputFolderPath;
    FILE[]
        FileArray;
    long[ long ]
        RepetitionCountMap;
    string[]
        ClippedLineArray;
    bool
        FilesAreIterated,
        FilesAreSelected,
        FilesMustBeSelected,
        FilesMustNotBeSelected,
        FilesAreMarked,
        FilesMustBeMarked,
        FilesMustNotBeMarked,
        FilesMustHaveLineInterval;

    // -- OPERATIONS

    void Abort(
        string message
        )
    {
        if ( LineIndex < LineArray.length )
        {
            writeln( "*** ERROR : ", FilePathArray[ LineIndex ], "(", LineIndexArray[ LineIndex ], ") : ", message );
        }
        else
        {
            writeln( "*** ERROR : ", message );
        }

        exit( -1 );
    }

    // ~~

    long GetValidLineIndex(
        string[] line_array,
        long line_index
        )
    {
        if ( line_index < 0
             || line_index > line_array.length )
        {
            Abort( "Invalid line index : " ~ line_index.to!string() );
        }

        return line_index;
    }

    // ~~

    long GetLineIndex(
        string[] line_array,
        string line_index_expression,
        FILE file = null
        )
    {
        if ( line_index_expression == "$" )
        {
            return GetValidLineIndex( line_array, line_array.length.to!long() );
        }
        else if ( line_index_expression.startsWith( "$-" ) )
        {
            return GetValidLineIndex( line_array, line_array.length.to!long() - Script.GetValue( line_index_expression[ 2 .. $ ], file ).GetInteger() );
        }
        else if ( line_index_expression.startsWith( "$+" ) )
        {
            return GetValidLineIndex( line_array, line_array.length.to!long() + Script.GetValue( line_index_expression[ 2 .. $ ], file ).GetInteger() );
        }
        else
        {
            return GetValidLineIndex( line_array, Script.GetValue( line_index_expression, file ).GetInteger() );
        }
    }

    // ~~

    long GetValidCharacterIndex(
        string line,
        long character_index
        )
    {
        if ( character_index < 0
             || character_index > line.length )
        {
            Abort( "Invalid character index : " ~ character_index.to!string() );
        }

        return character_index;
    }

    // ~~

    long GetCharacterIndex(
        string line,
        string character_index_expression,
        FILE file = null
        )
    {
        if ( character_index_expression == "$" )
        {
            return GetValidCharacterIndex( line, line.length.to!long() );
        }
        else if ( character_index_expression.startsWith( "$-" ) )
        {
            return GetValidCharacterIndex( line, line.length.to!long() - Script.GetValue( character_index_expression[ 2 .. $ ], file ).GetInteger() );
        }
        else if ( character_index_expression.startsWith( "$+" ) )
        {
            return GetValidCharacterIndex( line, line.length.to!long() + Script.GetValue( character_index_expression[ 2 .. $ ], file ).GetInteger() );
        }
        else
        {
            return GetValidCharacterIndex( line, Script.GetValue( character_index_expression, file ).GetInteger() );
        }
    }

    // ~~

    string RemoveLastTabulation(
        string text
        )
    {
        long
            new_length,
            old_length;

        new_length = text.length;

        if ( new_length > 0 )
        {
            if ( text[ new_length - 1 ] == '\t' )
            {
                --new_length;
            }
            else
            {
                old_length = new_length;

                while ( new_length > 0
                        && text[ new_length - 1 ] == ' '
                        && new_length > old_length - TabulationSpaceCount )
                {
                    --new_length;
                }
            }
        }

        text.length = new_length;

        return text;
    }

    // ~~

    string RemoveLastCharacters(
        string text,
        long removed_character_count
        )
    {
        if ( text.length > removed_character_count )
        {
            text.length -= removed_character_count;
        }
        else
        {
            text.length = 0;
        }

        return text;
    }

    // ~~

    void Load(
        string file_path
        )
    {
        bool
            it_is_in_string_literal;
        char
            character;
        long
            character_index;
        string
            line;
        string[]
            line_array;

        if ( file_path.exists() )
        {
            line_array = file_path.readText().replace( "\r", "" ).replace( "\t", "    " ).Split();

            foreach ( line_index; 0 .. line_array.length )
            {
                line = line_array[ line_index ].stripRight();

                if ( line.length > 0
                     && line[ 0 ] != '#' )
                {
                    if ( line[ 0 ] == ':'
                         || line[ 0 ] == ' '
                         || line.indexOf( ' ' ) < 0 )
                    {
                        LineArray ~= line;
                        LineIndexArray ~= line_index + 1;
                        FilePathArray ~= file_path;
                    }
                    else
                    {
                        LineArray ~= "";
                        LineIndexArray ~= line_index + 1;
                        FilePathArray ~= file_path;

                        it_is_in_string_literal = false;

                        for ( character_index = 0;
                              character_index < line.length;
                              ++character_index )
                        {
                            character = line[ character_index ];

                            if ( it_is_in_string_literal )
                            {
                                LineArray[ $ - 1 ] ~= character;

                                if ( character == '`' )
                                {
                                    it_is_in_string_literal = false;
                                }
                                else if ( character == '\\'
                                          && character_index + 1 < line.length )
                                {
                                    LineArray[ $ - 1 ] ~= line[ ++character_index ];

                                    if ( "@$%".indexOf( line[ character_index ] ) >= 0 )
                                    {
                                        while ( character_index + 1 < line.length )
                                        {
                                            LineArray[ $ - 1 ] ~= line[ ++character_index ];

                                            if ( line[ character_index ] == '\\' )
                                            {
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                            else if ( character == ' ' )
                            {
                                LineArray ~= "    ";
                                LineIndexArray ~= line_index + 1;
                                FilePathArray ~= file_path;
                            }
                            else
                            {
                                LineArray[ $ - 1 ] ~= character;

                                if ( character == '`' )
                                {
                                    it_is_in_string_literal = true;
                                }
                            }
                        }
                    }
                }
            }
        }
        else
        {
            Abort( "Invalid file path : " ~ file_path );
        }
    }

    // ~~

    string Strip(
        string argument
        )
    {
        bool
            it_is_in_string_literal;
        char
            character,
            delimiter_character;
        long
            character_index;

        if ( !FirstSpacesAreChecked )
        {
            argument = argument.stripLeft();
        }

        if ( !LastSpacesAreChecked )
        {
            argument = argument.stripRight();
        }

        if ( !InnerSpacesAreChecked )
        {
            character_index = 0;

            while ( character_index < argument.length
                    && argument[ character_index ] == ' ' )
            {
                ++character_index;
            }

            it_is_in_string_literal = false;
            delimiter_character = 0;

            while ( character_index < argument.length )
            {
                character = argument[ character_index ];

                if ( it_is_in_string_literal )
                {
                    if ( character == delimiter_character )
                    {
                        it_is_in_string_literal = false;
                    }
                    else if ( character == '\\' )
                    {
                        character_index += 2;

                        continue;
                    }
                }
                else
                {
                    if ( character == '\''
                         || character == '\"'
                         || character == '`' )
                    {
                        it_is_in_string_literal = true;

                        delimiter_character = character;
                    }
                    else if ( character == ' '
                              && character_index > 0
                              && argument[ character_index - 1 ] == ' ' )
                    {
                        argument = argument[ 0 .. character_index ] ~ argument[ character_index + 1 .. $ ];

                        continue;
                    }
                }

                ++character_index;
            }
        }

        return argument;
    }

    // ~~

    string[] Strip(
        string[] argument_array
        )
    {
        string[]
            stripped_argument_array;

        stripped_argument_array.length = argument_array.length;

        foreach ( argument_index; 0 .. argument_array.length )
        {
            stripped_argument_array[ argument_index ]
                = Strip( argument_array[ argument_index ] );
        }

        return stripped_argument_array;
    }

    // ~~

    string Unquote(
        string argument,
        FILE file = null
        )
    {
        char
            character;
        long
            character_index,
            function_part_index,
            part_index;
        string
            function_part,
            part,
            unquoted_argument,
            value;
        string[]
            part_array;

        if ( QuotationIsEnabled
             && argument.length >= 2
             && argument[ 0 ] == '`'
             && argument[ $ - 1 ] == '`' )
        {
            argument = argument[ 1 .. $ - 1 ];

            for ( character_index = 0;
                  character_index < argument.length;
                  ++character_index )
            {
                character = argument[ character_index ];

                if ( character == '\\'
                     && character_index + 1 < argument.length )
                {
                    character = argument[ ++character_index ];

                    if ( character == '\\' )
                    {
                        unquoted_argument ~= '\\';
                    }
                    else if ( character == '`' )
                    {
                        unquoted_argument ~= '`';
                    }
                    else if ( character == 'r' )
                    {
                        unquoted_argument ~= '\r';
                    }
                    else if ( character == 'n' )
                    {
                        unquoted_argument ~= '\n';
                    }
                    else if ( character == 't' )
                    {
                        unquoted_argument ~= '\t';
                    }
                    else if ( character == 'd' )
                    {
                        unquoted_argument = RemoveLastTabulation( unquoted_argument );
                    }
                    else if ( character == 'b' )
                    {
                        unquoted_argument = RemoveLastCharacters( unquoted_argument, 1 );
                    }
                    else if ( character == ' '
                              && file !is null )
                    {
                        unquoted_argument ~= file.Indentation;
                    }
                    else if ( "@$%".indexOf( character ) >= 0 )
                    {
                        part_array = null;

                        while ( character_index < argument.length )
                        {
                            character = argument[ character_index ];

                            if ( character == '\\' )
                            {
                                break;
                            }
                            else
                            {
                                if ( "@$%".indexOf( character ) >= 0 )
                                {
                                    part_array ~= "";
                                }

                                part_array[ $ - 1 ] ~= character;
                            }

                            ++character_index;
                        }

                        for ( part_index = 0;
                              part_index < part_array.length;
                              ++part_index )
                        {
                            part = part_array[ part_index ];

                            if ( part.length < 2 )
                            {
                                Abort( "Invalid escape sequence : " ~ part );
                            }

                            if ( part[ 0 ] != '@' )
                            {
                                if ( part[ 0 ] == '%' )
                                {
                                    if ( part[ 1 ] >= '0'
                                         && part[ 1 ] <= '9' )
                                    {
                                        value = GetFunctionArgument( part[ 1 .. $ ].GetInteger() );
                                    }
                                    else
                                    {
                                        value = GetVariable( part, file );
                                    }
                                }
                                else if ( part[ 0 ] == '$' )
                                {
                                    if ( part[ 1 ] >= '0'
                                         && part[ 1 ] <= '9' )
                                    {
                                        value = GetScriptArgument( part[ 1 .. $ ].GetInteger() );
                                    }
                                    else
                                    {
                                        value = GetVariable( part, file );
                                    }
                                }

                                for ( function_part_index = part_index - 1;
                                      function_part_index >= 0
                                      && part_array[ function_part_index ][ 0 ] == '@';
                                      --function_part_index )
                                {
                                    value = GetFunctionValue( part_array[ function_part_index ][ 1 .. $ ], [ value ] );
                                }

                                unquoted_argument ~= value;
                            }
                        }
                    }
                }
                else
                {
                    unquoted_argument ~= character;
                }
            }

            return unquoted_argument;
        }
        else
        {
            return argument;
        }
    }

    // ~~

    string[] Unquote(
        string[] argument_array,
        FILE file = null
        )
    {
        string[]
            unquoted_argument_array;

        if ( QuotationIsEnabled )
        {
            unquoted_argument_array.length = argument_array.length;

            foreach ( argument_index; 0 .. argument_array.length )
            {
                unquoted_argument_array[ argument_index ]
                    = Unquote( argument_array[ argument_index ], file );
            }

            return unquoted_argument_array.Join().Split();
        }
        else
        {
            return argument_array.Join().Split();
        }
    }

    // ~~

    bool IsArgument(
        long patch_line_index
        )
    {
        return
            patch_line_index >= 0
            && patch_line_index < LineArray.length
            && LineArray[ patch_line_index ].startsWith( "    " );
    }

    // ~~

    bool HasArgument(
        )
    {
        return IsArgument( LineIndex + 1 );
    }

    // ~~

    string GetArgument(
        )
    {
        string
            argument;

        if ( HasArgument() )
        {
            ++LineIndex;

            argument = LineArray[ LineIndex ][ 4 .. $ ];

            if ( VerboseOptionIsEnabled )
            {
                writeln( FilePathArray[ LineIndex ], "[", LineIndexArray[ LineIndex ], "]     ", argument );
            }

            return argument;
        }

        Abort( "Missing argument" );

        return "";
    }

    // ~~

    string[] GetArgumentArray(
        )
    {
        string[]
            argument_array;

        while ( HasArgument() )
        {
            argument_array ~= GetArgument();
        }

        return argument_array.Join().Split();
    }

    // ~~

    long GetValidLineIndex(
        long line_index
        )
    {
        if ( line_index < 0
             || line_index > LineArray.length )
        {
            Abort( "Invalid line index : " ~ line_index.to!string() );
        }

        return line_index;
    }

    // ~~

    long GetLabelLineIndex(
        string label
        )
    {
        long
            line_index;
        string
            label_line;

        label_line = ":" ~ label;

        for ( line_index = LineIndex - 1;
              line_index >= 0;
              --line_index )
        {
            if ( LineArray[ line_index ] == label_line )
            {
                return line_index;
            }
        }

        for ( line_index = LineIndex;
              line_index < LineArray.length;
              ++line_index )
        {
            if ( LineArray[ line_index ] == label_line )
            {
                return line_index;
            }
        }

        Abort( "Invalid label : " ~ label );

        return 0;
    }

    // ~~

    string GetScriptArgument(
        long argument_index
        )
    {
        if ( argument_index < ArgumentArray.length )
        {
            return ArgumentArray[ argument_index ];
        }

        Abort( "Invalid script argument : " ~ argument_index.to!string() );

        return "";
    }

    // ~~

    string GetFunctionArgument(
        long argument_index
        )
    {
        CALL
            call;

        if ( CallArray.length > 0 )
        {
            call = CallArray[ $ - 1 ];

            if ( argument_index < call.ArgumentArray.length )
            {
                return call.ArgumentArray[ argument_index ];
            }
        }
        else
        {
            Abort( "Missing function call" );
        }

        Abort( "Invalid function argument : " ~ argument_index.to!string() );

        return "";
    }

    // ~~

    void SetVariable(
        string variable_name,
        string variable_value,
        FILE file = null
        )
    {
        string
            * variable;

        if ( variable_name.length >= 2
             && variable_name[ 0 ] == '%'
             && variable_name[ 1 .. $ ].IsIdentifier()
             && file !is null )
        {
            file.VariableMap[ variable_name[ 1 .. $ ] ] = variable_value;
        }
        else if ( variable_name.length >= 2
             && variable_name[ 0 ] == '$'
             && variable_name[ 1 .. $ ].IsIdentifier() )
        {
            VariableMap[ variable_name[ 1 .. $ ] ] = variable_value;
        }
        else if ( variable_name.IsIdentifier() )
        {
            if ( file is null )
            {
                VariableMap[ variable_name ] = variable_value;
            }
            else
            {
                file.VariableMap[ variable_name ] = variable_value;
            }
        }
        else
        {
            Abort( "Invalid variable : " ~ variable_name );
        }
    }

    // ~~

    string GetVariable(
        string variable_name,
        FILE file = null
        )
    {
        string
            * variable;

        if ( variable_name.length >= 2
             && variable_name[ 0 ] == '%' )
        {
            if ( variable_name.length == 2
                 && variable_name[ 1 .. $ ].IsNatural() )
            {
                return GetFunctionArgument( variable_name[ 1 .. $ ].GetInteger() );
            }
            else if ( variable_name[ 1 .. $ ].IsIdentifier()
                      && file !is null )
            {
                variable = variable_name[ 1 .. $ ] in file.VariableMap;

                if ( variable !is null )
                {
                    return *variable;
                }
            }
        }
        else if ( variable_name.length >= 2
                  && variable_name[ 0 ] == '$' )
        {
            if ( variable_name.length == 2
                 && variable_name[ 1 .. $ ].IsNatural() )
            {
                return GetScriptArgument( variable_name[ 1 .. $ ].GetInteger() );
            }
            else if ( variable_name[ 1 .. $ ].IsIdentifier() )
            {
                variable = variable_name[ 1 .. $ ] in VariableMap;

                if ( variable !is null )
                {
                    return *variable;
                }
            }
        }
        else if ( variable_name.IsIdentifier() )
        {
            if ( file !is null )
            {
                variable = variable_name in file.VariableMap;

                if ( variable !is null )
                {
                    return *variable;
                }
            }

            variable = variable_name in VariableMap;

            if ( variable !is null )
            {
                return *variable;
            }
            else
            {
                return GetFunctionValue( variable_name, null, file );
            }
        }

        Abort( "Invalid variable : " ~ variable_name );

        return "";
    }

    // ~~

    long GetBinaryOperatorLevel(
        string token
        )
    {
        if ( token == "||" )
        {
            return 10;
        }
        else if ( token == "&&" )
        {
            return 9;
        }
        else if ( token == "<"
             || token == "<="
             || token == "=="
             || token == "!="
             || token == ">"
             || token == ">=" )
        {
            return 8;
        }
        else if ( token == "." )
        {
            return 7;
        }
        else if ( token == "~" )
        {
            return 6;
        }
        else if ( token == "#"
             || token == "#^"
             || token == "#$" )
        {
            return 5;
        }
        else if ( token == "@"
             || token == "@^"
             || token == "@$" )
        {
            return 4;
        }
        else if ( token == "+"
             || token == "-" )
        {
            return 3;
        }
        else if ( token == "*"
             || token == "/"
             || token == "%" )
        {
            return 2;
        }
        else if ( token == "&"
             || token == "|"
             || token == "^" )
        {
            return 1;
        }
        else if ( token == "<<"
             || token == ">>" )
        {
            return 0;
        }

        return -1;
    }

    // ~~

    long GetBinaryOperatorTokenIndex(
        string[] token_array
        )
    {
        long
            best_binary_operator_level,
            nesting_level,
            binary_operator_level,
            binary_operator_token_index;

        binary_operator_token_index = -1;
        best_binary_operator_level = -1;
        nesting_level = 0;

        foreach ( token_index, token; token_array )
        {
            if ( token == "(" )
            {
                ++nesting_level;
            }
            else if ( token == ")" )
            {
                --nesting_level;
            }
            else if ( nesting_level == 0 )
            {
                binary_operator_level = GetBinaryOperatorLevel( token );

                if ( binary_operator_level >= 0
                     && binary_operator_level >= best_binary_operator_level )
                {
                    best_binary_operator_level = binary_operator_level;
                    binary_operator_token_index = token_index;
                }
            }
        }

        return binary_operator_token_index;
    }

    // ~~

    string GetFunctionValue(
        string function_name,
        string[] argument_array,
        FILE file = null
        )
    {
        long
            label_line_index;
        CALL
            call;

        if ( function_name == "LowerCase"
             && argument_array.length == 1 )
        {
            return GetLowerCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "UpperCase"
                  && argument_array.length == 1 )
        {
            return GetUpperCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "MinorCase"
                  && argument_array.length == 1 )
        {
            return GetMinorCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "MajorCase"
                  && argument_array.length == 1 )
        {
            return GetMajorCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "CamelCase"
                  && argument_array.length == 1 )
        {
            return GetCamelCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "SnakeCase"
                  && argument_array.length == 1 )
        {
            return GetSnakeCaseText( argument_array[ 0 ] );
        }
        else if ( function_name == "LineCount"
                  && argument_array.length == 1 )
        {
            return argument_array[ 0 ].Split().length.to!string();
        }
        else if ( function_name == "LineArray"
                  && argument_array.length == 0
                  && file !is null )
        {
            return file.LineArray.Join();
        }
        else if ( function_name == "LineCount"
                  && argument_array.length == 0
                  && file !is null )
        {
            return file.LineArray.length.to!string();
        }
        else if ( function_name == "HasLineInterval"
                  && argument_array.length == 0
                  && file !is null )
        {
            return file.HasLineInterval() ? "1" : "0";
        }
        else if ( function_name == "LineIndex"
                  && argument_array.length == 0
                  && file !is null )
        {
            return file.LineIndex.to!string();
        }
        else if ( function_name == "PostLineIndex"
                  && argument_array.length == 0
                  && file !is null )
        {
            return file.PostLineIndex.to!string();
        }
        else
        {
            label_line_index = GetLabelLineIndex( function_name );

            call = new CALL();
            call.ArgumentArray = argument_array;
            call.ReturnLineIndex = LineIndex;

            CallArray ~= call;

            LineIndex = label_line_index;

            while ( ExecuteLine() > 0 )
            {
                ++LineIndex;
            }

            return Result;
        }

        Abort( "Invalid function call : " ~ function_name ~ " " ~ argument_array.join( ' ' ) );

        return "";
    }

    // ~~

    string GetFunctionValue(
        string[] token_array,
        FILE file = null
        )
    {
        long
            last_token_index,
            nesting_level,
            token_index;
        string
            function_name,
            last_token,
            token;
        string[]
            argument_array;

        if ( token_array.length > 0 )
        {
            function_name = token_array[ 0 ];

            for ( token_index = 1;
                  token_index < token_array.length;
                  ++token_index )
            {
                token = token_array[ token_index ];

                if ( token == "(" )
                {
                    nesting_level = 0;

                    for ( last_token_index = token_index;
                          last_token_index < token_array.length;
                          ++last_token_index )
                    {
                        last_token = token_array[ last_token_index ];

                        if ( last_token == "(" )
                        {
                            ++nesting_level;
                        }
                        else if ( last_token == ")" )
                        {
                            --nesting_level;

                            if ( nesting_level == 0 )
                            {
                                break;
                            }
                        }
                    }

                    if ( last_token_index < token_array.length )
                    {
                        argument_array ~= GetValue( token_array[ token_index + 1 .. last_token_index ], file );

                        token_index = last_token_index;
                    }
                    else
                    {
                        Abort( "Invalid expression : " ~ token_array.join( ' ' ) );
                    }
                }
                else
                {
                    argument_array ~= GetValue( token, file );
                }
            }

            return GetFunctionValue( function_name, argument_array, file );
        }

        Abort( "Invalid function call" );

        return "";
    }

    // ~~

    string GetValue(
        string token,
        FILE file = null
        )
    {
        if ( token.startsWith( '`' ) )
        {
            return Unquote( token, file );
        }
        else if ( token.IsInteger()
                  || token == "$"
                  || token.startsWith( "$-" )
                  || token.startsWith( "$+" ) )
        {
            return token;
        }
        else
        {
            return GetVariable( token, file );
        }
    }

    // ~~

    string GetValue(
        string[] token_array,
        FILE file = null
        )
    {
        long
            binary_operator_token_index,
            character_index,
            first_value_integer,
            line_index,
            second_value_integer;
        string
            binary_operator,
            first_value,
            second_value;
        string
            expression_value;
        string[]
            line_array;

        if ( token_array.length == 1 )
        {
            return GetValue( token_array[ 0 ], file );
        }
        else
        {
            binary_operator_token_index = GetBinaryOperatorTokenIndex( token_array );

            if ( binary_operator_token_index > 0 )
            {
                first_value = GetValue( token_array[ 0 .. binary_operator_token_index ], file );
                binary_operator = token_array[ binary_operator_token_index ];
                second_value = GetValue( token_array[ binary_operator_token_index + 1 .. $ ], file );

                if ( first_value.IsInteger()
                     && second_value.IsInteger() )
                {
                    first_value_integer = first_value.GetInteger();
                    second_value_integer = second_value.GetInteger();

                    if ( binary_operator == "||" )
                    {
                        return ( first_value_integer || second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "&&" )
                    {
                        return ( first_value_integer && second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "<" )
                    {
                        return ( first_value_integer < second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "<=" )
                    {
                        return ( first_value_integer <= second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "==" )
                    {
                        return ( first_value_integer == second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "!=" )
                    {
                        return ( first_value_integer != second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == ">=" )
                    {
                        return ( first_value_integer >= second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == ">" )
                    {
                        return ( first_value_integer > second_value_integer ) ? "1" : "0";
                    }
                    else if ( binary_operator == "+" )
                    {
                        return ( first_value_integer + second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "-" )
                    {
                        return ( first_value_integer - second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "*" )
                    {
                        return ( first_value_integer * second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "/" )
                    {
                        return ( first_value_integer / second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "%" )
                    {
                        return ( first_value_integer % second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "&" )
                    {
                        return ( first_value_integer & second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "|" )
                    {
                        return ( first_value_integer | second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "^" )
                    {
                        return ( first_value_integer ^ second_value_integer ).to!string();
                    }
                    else if ( binary_operator == "<<" )
                    {
                        return ( first_value_integer << second_value_integer ).to!string();
                    }
                    else if ( binary_operator == ">>" )
                    {
                        return ( first_value_integer >> second_value_integer ).to!string();
                    }
                }
                else
                {
                    if ( binary_operator == "." )
                    {
                        if ( first_value.length > 0 )
                        {
                            return first_value ~ "\n" ~ second_value;
                        }
                        else
                        {
                            return first_value ~ second_value;
                        }
                    }
                    else if ( binary_operator == "~" )
                    {
                        return first_value ~ second_value;
                    }
                    else if ( binary_operator == "<" )
                    {
                        return ( first_value < second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == "<=" )
                    {
                        return ( first_value <= second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == "==" )
                    {
                        return ( first_value == second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == "!=" )
                    {
                        return ( first_value != second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == ">=" )
                    {
                        return ( first_value >= second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == ">" )
                    {
                        return ( first_value > second_value ) ? "1" : "0";
                    }
                    else if ( binary_operator == "#"
                              || binary_operator == "#^"
                              || binary_operator == "#$" )
                    {
                        line_array = first_value.Split();
                        line_index = GetLineIndex( line_array, second_value, file );

                        if ( binary_operator == "#"
                             && line_index < line_array.length )
                        {
                            return line_array[ line_index ];
                        }
                        else if ( binary_operator == "#^" )
                        {
                            return line_array[ line_index .. $ ].Join();
                        }
                        else if ( binary_operator == "#$" )
                        {
                            return line_array[ 0 .. line_index ].Join();
                        }
                    }
                    else if ( binary_operator == "@"
                              || binary_operator == "@^"
                              || binary_operator == "@$" )
                    {
                        character_index = GetCharacterIndex( first_value, second_value, file );

                        if ( binary_operator == "@"
                             && character_index < first_value.length )
                        {
                            return first_value[ character_index ].to!string();
                        }
                        else if ( binary_operator == "@^" )
                        {
                            return first_value[ character_index .. $ ];
                        }
                        else if ( binary_operator == "@$" )
                        {
                            return first_value[ 0 .. character_index ];
                        }
                    }
                }
            }
            else if ( token_array.length >= 2
                      && token_array[ 0 ] == "("
                      && token_array[ $ - 1 ] == ")" )
            {
                return GetValue( token_array[ 1 .. $ - 1 ], file );
            }
            else
            {
                return GetFunctionValue( token_array, file );
            }
        }

        Abort( "Invalid expression : " ~ token_array.join( ' ' ) );

        return "";
    }

    // ~~

    bool GetBooleanValue(
        string[] expression_token_array,
        FILE file = null
        )
    {
        string
            expression_value;

        expression_value = GetValue( expression_token_array, file );

        if ( expression_value == "0" )
        {
            return false;
        }
        else if ( expression_value == "1" )
        {
            return true;
        }

        Abort( "Invalid condition" );

        return false;
    }

    // ~~

    void EvaluateAssignment(
        ref string variable_value,
        string assignment_operator,
        string[] expression_token_array,
        FILE file = null
        )
    {
        long
            expression_value_integer,
            variable_value_integer;
        string
            expression_value;

        if ( assignment_operator == ":=" )
        {
            variable_value = Unquote( expression_token_array, file ).Join();
        }
        else
        {
            expression_value = GetValue( expression_token_array, file );

            if ( assignment_operator == ".=" )
            {
                if ( variable_value.length > 0 )
                {
                    variable_value ~= '\n';
                }

                variable_value ~= expression_value;
            }
            else if ( assignment_operator == "=" )
            {
                variable_value = expression_value;
            }
            else if ( assignment_operator == "~=" )
            {
                variable_value ~= expression_value;
            }
            else if ( variable_value.IsInteger()
                      && expression_value.IsInteger() )
            {
                variable_value_integer = variable_value.GetInteger();
                expression_value_integer = expression_value.GetInteger();

                if ( assignment_operator == "+=" )
                {
                    variable_value_integer += expression_value_integer;
                }
                else if ( assignment_operator == "-=" )
                {
                    variable_value_integer -= expression_value_integer;
                }
                else if ( assignment_operator == "*=" )
                {
                    variable_value_integer *= expression_value_integer;
                }
                else if ( assignment_operator == "/=" )
                {
                    if ( expression_value_integer != 0 )
                    {
                        variable_value_integer /= expression_value_integer;
                    }
                    else
                    {
                        Abort( "Null divisor" );
                    }
                }
                else if ( assignment_operator == "%=" )
                {
                    if ( expression_value_integer != 0 )
                    {
                        variable_value_integer %= expression_value_integer;
                    }
                    else
                    {
                        Abort( "Null divisor" );
                    }
                }
                else if ( assignment_operator == "&=" )
                {
                    variable_value_integer &= expression_value_integer;
                }
                else if ( assignment_operator == "|=" )
                {
                    variable_value_integer |= expression_value_integer;
                }
                else if ( assignment_operator == "^=" )
                {
                    variable_value_integer ^= expression_value_integer;
                }
                else if ( assignment_operator == "<<=" )
                {
                    variable_value_integer <<= expression_value_integer;
                }
                else if ( assignment_operator == ">>=" )
                {
                    variable_value_integer >>= expression_value_integer;
                }
                else
                {
                    Abort( "Invalid assignment operator : " ~ assignment_operator );
                }

                variable_value = variable_value_integer.to!string();
            }
            else
            {
                Abort( "Invalid assignment" );
            }
        }
    }

    // ~~

    void AssignVariable(
        string variable_name,
        string assignment_operator,
        string[] expression_token_array,
        FILE file = null
        )
    {
        bool
            it_is_file_variable,
            it_is_script_variable;
        string
            * variable;

        it_is_file_variable = false;
        it_is_script_variable = false;

        if ( variable_name.startsWith( '%' ) )
        {
            variable_name = variable_name[ 1 .. $ ];

            it_is_file_variable = true;

            if ( file is null )
            {
                Abort( "Invalid variable : " ~ variable_name );
            }
        }
        else if ( variable_name.startsWith( '$' ) )
        {
            variable_name = variable_name[ 1 .. $ ];

            it_is_script_variable = true;
        }

        if ( variable_name.IsIdentifier() )
        {
            if ( assignment_operator == "="
                 || assignment_operator == ":=" )
            {
                if ( it_is_file_variable )
                {
                    if ( ( variable_name in file.VariableMap ) is null )
                    {
                        file.VariableMap[ variable_name ] = "";
                    }
                }
                else if ( it_is_script_variable )
                {
                    if ( ( variable_name in VariableMap ) is null )
                    {
                        VariableMap[ variable_name ] = "";
                    }
                }
                else
                {
                    it_is_file_variable = ( file !is null && ( variable_name in file.VariableMap ) !is null );
                    it_is_script_variable = ( ( variable_name in VariableMap ) !is null );

                    if ( it_is_file_variable )
                    {
                        it_is_script_variable = false;
                    }
                    else if ( !it_is_script_variable )
                    {
                        if ( file is null )
                        {
                            VariableMap[ variable_name ] = "";

                            it_is_script_variable = true;
                        }
                        else
                        {
                            file.VariableMap[ variable_name ] = "";

                            it_is_file_variable = true;
                        }
                    }
                }
            }

            if ( !it_is_file_variable
                 && !it_is_script_variable )
            {
                it_is_file_variable = ( file !is null && ( variable_name in file.VariableMap ) !is null );
                it_is_script_variable = ( ( variable_name in VariableMap ) !is null );
            }

            if ( it_is_file_variable )
            {
                EvaluateAssignment( file.VariableMap[ variable_name ], assignment_operator, expression_token_array, file );

                return;
            }
            else if ( it_is_script_variable )
            {
                EvaluateAssignment( VariableMap[ variable_name ], assignment_operator, expression_token_array, file );

                return;
            }
        }

        Abort( "Invalid variable : " ~ variable_name );
    }

    // ~~

    void PrintVariableValue(
        string variable_name,
        string variable_value
        )
    {
        string[]
            variable_line_array;

        if ( variable_value.indexOf( '\n' ) >= 0 )
        {
            writeln( variable_name, " : " );

            variable_line_array = variable_value.Split();

            foreach ( variable_line; variable_line_array )
            {
                writeln( "    ", variable_line );
            }
        }
        else
        {
            writeln( variable_name, " : ", variable_value );
        }
    }

    // ~~

    void CreateFolder(
        string folder_path
        )
    {
        if ( folder_path != ""
             && folder_path != "/"
             && folder_path != "./"
             && !folder_path.exists() )
        {
            writeln( "Creating folder : ", folder_path );

            if ( !PreviewOptionIsEnabled )
            {
                try
                {
                    folder_path.mkdirRecurse();
                }
                catch ( FileException file_exception )
                {
                    Abort( "Can't create folder : " ~ folder_path );
                }
            }
        }
    }

    // ~~

    void EnableQuotation(
        )
    {
        QuotationIsEnabled = true;
    }

    // ~~

    void DisableQuotation(
        )
    {
        QuotationIsEnabled = false;
    }

    // ~~

    void CheckFirstSpaces(
        )
    {
        FirstSpacesAreChecked = true;
    }

    // ~~

    void IgnoreFirstSpaces(
        )
    {
        FirstSpacesAreChecked = false;
    }

    // ~~

    void CheckInnerSpaces(
        )
    {
        InnerSpacesAreChecked = true;
    }

    // ~~

    void IgnoreInnerSpaces(
        )
    {
        InnerSpacesAreChecked = false;
    }

    // ~~

    void CheckLastSpaces(
        )
    {
        LastSpacesAreChecked = true;
    }

    // ~~

    void IgnoreLastSpaces(
        )
    {
        LastSpacesAreChecked = false;
    }

    // ~~

    void CheckSideSpaces(
        )
    {
        FirstSpacesAreChecked = true;
        LastSpacesAreChecked = true;
    }

    // ~~

    void IgnoreSideSpaces(
        )
    {
        FirstSpacesAreChecked = false;
        LastSpacesAreChecked = false;
    }

    // ~~

    void SetTabulationSpaceCount(
        )
    {
        TabulationSpaceCount = Unquote( GetArgument() ).GetInteger();

        if ( TabulationSpaceCount < 0
             || TabulationSpaceCount > 8 )
        {
            Abort( "Invalid tabulation space count" );
        }
    }

    // ~~

    void SetFolder(
        )
    {
        InputFolderPath = Unquote( GetArgument() );
        OutputFolderPath = InputFolderPath;

        VariableMap[ "InputFolder" ] = InputFolderPath;
        VariableMap[ "OutputFolder" ] = OutputFolderPath;
    }

    // ~~

    void SetInputFolder(
        )
    {
        InputFolderPath = Unquote( GetArgument() );

        VariableMap[ "InputFolder" ] = InputFolderPath;
    }

    // ~~

    void SetOutputFolder(
        )
    {
        OutputFolderPath = Unquote( GetArgument() );

        VariableMap[ "OutputFolder" ] = OutputFolderPath;
    }

    // ~~

    void RemoveFiles(
        )
    {
        string[]
            file_path_argument_array;

        file_path_argument_array = GetArgumentArray();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                foreach( ref file_path_argument; file_path_argument_array )
                {
                    try
                    {
                        remove( Unquote( file_path_argument, file ) );
                    }
                    catch ( FileException file_exception )
                    {
                        Abort( "Can't remove file" );
                    }
                }
            }
        }
        else
        {
            foreach( ref file_path_argument; file_path_argument_array )
            {
                try
                {
                    remove( Unquote( file_path_argument ) );
                }
                catch ( FileException file_exception )
                {
                    Abort( "Can't remove file" );
                }
            }
        }
    }

    // ~~

    void MoveFiles(
        )
    {
        string
            input_file_path_argument,
            output_file_path_argument;

        input_file_path_argument = GetArgument();
        output_file_path_argument = GetArgument();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                try
                {
                    rename(
                        Unquote( input_file_path_argument, file ),
                        Unquote( output_file_path_argument, file )
                        );
                }
                catch ( FileException file_exception )
                {
                    Abort( "Can't move file" );
                }
            }
        }
        else
        {
            try
            {
                rename(
                    Unquote( input_file_path_argument ),
                    Unquote( output_file_path_argument )
                    );
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't move file" );
            }
        }
    }

    // ~~

    void CopyFiles(
        )
    {
        string
            input_file_path_argument,
            output_file_path_argument;

        input_file_path_argument = GetArgument();
        output_file_path_argument = GetArgument();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                try
                {
                    copy(
                        Unquote( input_file_path_argument, file ),
                        Unquote( output_file_path_argument, file )
                        );
                }
                catch ( FileException file_exception )
                {
                    Abort( "Can't copy file" );
                }
            }
        }
        else
        {
            try
            {
                copy(
                    Unquote( input_file_path_argument ),
                    Unquote( output_file_path_argument )
                    );
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't copy file" );
            }
        }
    }

    // ~~

    void ReadFiles(
        )
    {
        FileArray = null;

        IncludeFiles();
    }

    // ~~

    void IncludeFiles(
        )
    {
        bool
            file_is_found;
        string
            file_name_filter,
            file_path_filter,
            folder_path,
            input_file_path,
            output_file_path;
        string[]
            file_path_filter_argument_array;
        SpanMode
            span_mode;
        FILE
            file;
        FILE[ string ]
            file_map;

        file_path_filter_argument_array = GetArgumentArray();

        foreach( ref file_path_filter_argument; file_path_filter_argument_array )
        {
            file_path_filter = InputFolderPath ~ Unquote( file_path_filter_argument );
            file_is_found = false;

            SplitFilePathFilter( file_path_filter, folder_path, file_name_filter, span_mode );

            foreach ( folder_entry; dirEntries( folder_path, file_name_filter, span_mode ) )
            {
                if ( folder_entry.isFile()
                     && ( folder_entry.name() in file_map ) is null )
                {
                    input_file_path = folder_entry.name();
                    output_file_path = OutputFolderPath ~ input_file_path[ InputFolderPath.length .. $ ];

                    file = new FILE();
                    file.ReadFile( input_file_path, output_file_path );
                    file.Select();

                    FileArray ~= file;

                    file_is_found = true;
                    file_map[ input_file_path ] = file;
                }
            }

            if ( !file_is_found
                 && !FilesAreSelected )
            {
                Abort( "File not found : " ~ file_path_filter );
            }
        }
    }

    // ~~

    void ExcludeFiles(
        )
    {
        bool
            file_is_excluded;
        string[]
            file_path_filter_argument_array;
        FILE[]
            file_array;

        file_path_filter_argument_array = GetArgumentArray();

        if ( file_path_filter_argument_array.length == 0 )
        {
            FileArray = null;
        }
        else
        {
            foreach ( ref file; FileArray )
            {
                file_is_excluded = false;

                foreach( ref file_path_filter_argument; file_path_filter_argument_array )
                {
                    if ( file.MatchesFilter( Unquote( file_path_filter_argument, file ) ) )
                    {
                        file_is_excluded = true;

                        break;
                    }
                }

                if ( !file_is_excluded )
                {
                    file_array ~= file;
                }
            }

            FileArray = file_array;
        }
    }

    // ~~

    void CreateFiles(
        )
    {
        string
            file_path;
        string[]
            file_path_argument_array;
        FILE
            file;

        file_path_argument_array = GetArgumentArray();

        foreach ( ref file_path_argument; file_path_argument_array )
        {
            file_path = Unquote( file_path_argument );

            file = new FILE();
            file.CreateFile( InputFolderPath ~ file_path, OutputFolderPath ~ file_path );
            file.Select();

            FileArray ~= file;
        }
    }

    // ~~

    void CreateFolders(
        )
    {
        string
            folder_path;
        string[]
            folder_path_argument_array;

        if ( !HasArgument() )
        {
            foreach ( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    file.CreateFolder();
                }
            }
        }
        else
        {
            folder_path_argument_array = GetArgumentArray();

            foreach ( ref folder_path_argument; folder_path_argument_array )
            {
                folder_path = Unquote( folder_path_argument );

                CreateFolder( OutputFolderPath ~ folder_path );
            }
        }
    }

    // ~~

    void WriteFiles(
        )
    {
        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.WriteFile();
            }
        }

        FileArray = null;
    }

    // ~~

    void Print(
        )
    {
        string[]
            expression_argument_array;

        expression_argument_array = GetArgumentArray();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    writeln( GetValue( expression_argument_array, file ) );
                }
            }
        }
        else
        {
            writeln( GetValue( expression_argument_array ) );
        }
    }

    // ~~

    void PrintRanges(
        )
    {
        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PrintRanges();
            }
        }
    }

    // ~~

    void PrintIntervals(
        )
    {
        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PrintIntervals();
            }
        }
    }

    // ~~

    void PrintLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        if ( HasArgument() )
        {
            line_index_expression_argument = GetArgument();
            post_line_index_expression_argument = GetArgument();
        }
        else
        {
            line_index_expression_argument = "0";
            post_line_index_expression_argument = "$";
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PrintLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void PrintSelectedLines(
        )
    {
        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PrintSelectedLines();
            }
        }
    }

    // ~~

    void PrintChangedLines(
        )
    {
        long
            dump_line_count;

        if ( HasArgument() )
        {
            dump_line_count = Unquote( GetArgument() ).GetInteger();
        }
        else
        {
            dump_line_count = 0;
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PrintChangedLines( dump_line_count );
            }
        }
    }

    // ~~

    void PrintArguments(
        )
    {
        foreach ( argument_index, ref argument; ArgumentArray )
        {
            PrintVariableValue( "$" ~ argument_index.to!string(), argument );
        }

        if ( CallArray.length > 0 )
        {
            foreach ( argument_index, ref argument; CallArray[ $ - 1 ].ArgumentArray )
            {
                PrintVariableValue( "%" ~ argument_index.to!string(), argument );
            }
        }
    }

    // ~~

    void PrintVariables(
        )
    {
        string
            variable_name;
        string *
            variable;

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                foreach ( character_index; 0 .. 26 )
                {
                    variable_name = "abcdefghijklmnopqrstuvwxyz"[ character_index .. character_index + 1 ];

                    variable = variable_name in file.VariableMap;

                    if ( variable !is null )
                    {
                        PrintVariableValue( variable_name, *variable );
                    }
                }
            }
        }
        else
        {
            foreach ( character_index; 0 .. 26 )
            {
                variable_name = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"[ character_index .. character_index + 1 ];

                variable = variable_name in VariableMap;

                if ( variable !is null )
                {
                    PrintVariableValue( variable_name, *variable );
                }
            }
        }
    }

    // ~~

    void SetFilePath(
        )
    {
        string
            output_file_path_argument;

        output_file_path_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetOutputPath( Unquote( output_file_path_argument, file ) );
            }
        }
    }

    // ~~

    void SetLineIndex(
        )
    {
        string
            line_index_expression_argument;

        line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetLineIndex( Unquote( line_index_expression_argument, file ) );
            }
        }
    }

    // ~~

    void SetLineCount(
        )
    {
        long
            line_count;

        line_count = Unquote( GetArgument() ).GetInteger();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetLineCount( line_count );
            }
        }
    }

    // ~~

    void SetLineRange(
        )
    {
        long
            line_count;
        string
            line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        line_count = Unquote( GetArgument() ).GetInteger();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetLineRange( Unquote( line_index_expression_argument, file ), line_count );
            }
        }
    }

    // ~~

    void SetPostLineIndex(
        )
    {
        string
            post_line_index_expression_argument;

        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetPostLineIndex( Unquote( post_line_index_expression_argument, file ) );
            }
        }
    }

    // ~~

    void SetLineInterval(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetLineInterval(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void ReplaceText(
        bool it_must_be_unquoted,
        bool it_must_be_quoted,
        bool it_must_be_in_identifier
        )
    {
        string
            line_index_expression_argument,
            new_text_argument,
            old_text_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        old_text_argument = GetArgument();
        new_text_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReplaceText(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( old_text_argument, file ),
                    Unquote( new_text_argument, file ),
                    it_must_be_unquoted,
                    it_must_be_quoted,
                    it_must_be_in_identifier
                    );
            }
        }
    }

    // ~~

    void ReplaceExpression(
        )
    {
        string
            line_index_expression_argument,
            new_text_argument,
            old_expression_argument,
            post_line_index_expression_argument;
        Regex!char
            old_expression;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        old_expression_argument = GetArgument();
        new_text_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                old_expression = regex( Unquote( old_expression_argument, file ) );

                file.ReplaceExpression(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    old_expression,
                    Unquote( new_text_argument, file )
                    );
            }
        }
    }

    // ~~

    void ReplaceTabulations(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReplaceTabulations(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void ReplaceSpaces(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReplaceSpaces(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void SelectFiles(
        )
    {
        string[]
            file_path_filter_argument_array;

        file_path_filter_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ItIsSelected = false;

                foreach ( ref file_path_filter_argument; file_path_filter_argument_array )
                {
                    if ( file.MatchesFilter( InputFolderPath ~ Unquote( file_path_filter_argument, file ) ) )
                    {
                        file.ItIsSelected = true;

                        break;
                    }
                }
            }
        }
    }

    // ~~

    void IgnoreFiles(
        )
    {
        string[]
            file_path_filter_argument_array;

        file_path_filter_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ItIsSelected = true;

                foreach ( ref file_path_filter_argument; file_path_filter_argument_array )
                {
                    if ( file.MatchesFilter( InputFolderPath ~ Unquote( file_path_filter_argument, file ) ) )
                    {
                        file.ItIsSelected = false;

                        break;
                    }
                }
            }
        }
    }

    // ~~

    void MarkFiles(
        )
    {
        string[]
            file_path_filter_argument_array;

        file_path_filter_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ItIsMarked = false;

                foreach ( ref file_path_filter_argument; file_path_filter_argument_array )
                {
                    if ( file.MatchesFilter( InputFolderPath ~ Unquote( file_path_filter_argument, file ) ) )
                    {
                        file.ItIsMarked = true;

                        break;
                    }
                }
            }
        }
    }

    // ~~

    void UnmarkFiles(
        )
    {
        string[]
            file_path_filter_argument_array;

        file_path_filter_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ItIsMarked = true;

                foreach ( ref file_path_filter_argument; file_path_filter_argument_array )
                {
                    if ( file.MatchesFilter( InputFolderPath ~ Unquote( file_path_filter_argument, file ) ) )
                    {
                        file.ItIsMarked = false;

                        break;
                    }
                }
            }
        }
    }

    // ~~

    void FindText(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument,
            text_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        text_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.FindText(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( text_argument, file ) )
                    );
            }
        }
    }

    // ~~

    void ReachText(
        )
    {
        string
            post_line_index_expression_argument,
            text_argument;

        post_line_index_expression_argument = GetArgument();
        text_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReachText(
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( text_argument, file ) )
                    );
            }
        }
    }

    // ~~

    void FindLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        string[]
            line_argument_array;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        line_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.FindLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( line_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void ReachLines(
        )
    {
        string
            post_line_index_expression_argument;
        string[]
            line_argument_array;

        post_line_index_expression_argument = GetArgument();
        line_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReachLines(
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( line_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void FindPrefixes(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        string[]
            prefix_argument_array;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        prefix_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.FindPrefixes(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( prefix_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void ReachPrefixes(
        )
    {
        string
            post_line_index_expression_argument;
        string[]
            prefix_argument_array;

        post_line_index_expression_argument = GetArgument();
        prefix_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReachPrefixes(
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( prefix_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void FindSuffixes(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        string[]
            suffix_argument_array;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        suffix_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.FindSuffixes(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( suffix_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void ReachSuffixes(
        )
    {
        string
            post_line_index_expression_argument;
        string[]
            suffix_argument_array;

        post_line_index_expression_argument = GetArgument();
        suffix_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.ReachSuffixes(
                    Unquote( post_line_index_expression_argument, file ),
                    Strip( Unquote( suffix_argument_array, file ) )
                    );
            }
        }
    }

    // ~~

    void FindExpressions(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        string[]
            expression_argument_array;
        Regex!char[]
            expression_array;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        expression_argument_array = GetArgumentArray();

        expression_array.length = expression_argument_array.length;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                foreach ( expression_argument_index, ref expression_argument; expression_argument_array )
                {
                    expression_array[ expression_argument_index ] = regex( Strip( Unquote( expression_argument, file ) ) );
                }

                file.FindExpressions(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    expression_array
                    );
            }
        }
    }

    // ~~

    void ReachExpressions(
        )
    {
        string
            post_line_index_expression_argument;
        string[]
            expression_argument_array;
        Regex!char[]
            expression_array;

        post_line_index_expression_argument = GetArgument();
        expression_argument_array = GetArgumentArray();

        expression_array.length = expression_argument_array.length;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                foreach ( expression_argument_index, ref expression_argument; expression_argument_array )
                {
                    expression_array[ expression_argument_index ] = regex( Strip( Unquote( expression_argument, file ) ) );
                }

                file.ReachExpressions(
                    Unquote( post_line_index_expression_argument, file ),
                    expression_array
                    );
            }
        }
    }

    // ~~

    void InsertLines(
        )
    {
        string
            line_index_expression_argument,
            character_index_expression_argument;
        string[]
            line_argument_array;

        line_index_expression_argument = GetArgument();
        character_index_expression_argument = GetArgument();
        line_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.InsertLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( line_argument_array, file )
                    );
            }
        }
    }

    // ~~

    void AddLines(
        )
    {
        string
            line_index_expression_argument;
        string[]
            line_argument_array;

        line_index_expression_argument = GetArgument();
        line_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.AddLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( line_argument_array, file )
                    );
            }
        }
    }

    // ~~

    void AddEmptyLines(
        )
    {
        long
            line_count;
        string
            line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        line_count = Unquote( GetArgument() ).GetInteger();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.AddEmptyLines(
                    Unquote( line_index_expression_argument, file ),
                    line_count
                    );
            }
        }
    }

    // ~~

    void RemoveLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemoveFirstEmptyLines(
        )
    {
        long
            line_count;
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            line_count = Unquote( GetArgument() ).GetInteger();
        }
        else
        {
            line_count = -1;
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveFirstEmptyLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    line_count
                    );
            }
        }
    }

    // ~~

    void RemoveLastEmptyLines(
        )
    {
        long
            line_count;
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            line_count = Unquote( GetArgument() ).GetInteger();
        }
        else
        {
            line_count = -1;
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveLastEmptyLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    line_count
                    );
            }
        }
    }

    // ~~

    void RemoveEmptyLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveEmptyLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemoveDoubleEmptyLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveDoubleEmptyLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void SkipLines(
        )
    {
        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SkipLines();
            }
        }
    }

    // ~~

    void SetLines(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        string[]
            line_argument_array;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        line_argument_array = GetArgumentArray();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.SetLines(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( line_argument_array, file )
                    );
            }
        }
    }

    // ~~

    void CopyLines(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_character_index_expression_argument,
            post_line_index_expression_argument,
            variable_name_argument;

        variable_name_argument = GetArgument();
        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            character_index_expression_argument = GetArgument();
            post_character_index_expression_argument = GetArgument();
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.CopyLines(
                    Unquote( variable_name_argument, file ),
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( post_character_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void CutLines(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_character_index_expression_argument,
            post_line_index_expression_argument,
            variable_name_argument;

        variable_name_argument = GetArgument();
        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            character_index_expression_argument = GetArgument();
            post_character_index_expression_argument = GetArgument();
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.CutLines(
                    Unquote( variable_name_argument, file ),
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( post_character_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void PasteLines(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            variable_name_argument;

        variable_name_argument = GetArgument();
        line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            character_index_expression_argument = GetArgument();
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.PasteLines(
                    Unquote( variable_name_argument, file ),
                    Unquote( line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void AddText(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_line_index_expression_argument,
            text_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        character_index_expression_argument = GetArgument();
        text_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.AddText(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( text_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemovePrefix(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument,
            prefix_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        prefix_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemovePrefix(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( prefix_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemoveSuffix(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument,
            suffix_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        suffix_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveSuffix(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( suffix_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemoveText(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_character_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        character_index_expression_argument = GetArgument();
        post_character_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveText(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( post_character_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void RemoveSideText(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_character_index_expression_argument,
            post_line_index_expression_argument;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        character_index_expression_argument = GetArgument();
        post_character_index_expression_argument = GetArgument();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveSideText(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    Unquote( post_character_index_expression_argument, file )
                    );
            }
        }
    }

    // ~~

    void AddSpaces(
        )
    {
        string
            character_index_expression_argument,
            line_index_expression_argument,
            post_line_index_expression_argument;
        long
            space_count;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();
        character_index_expression_argument = GetArgument();
        space_count = Unquote( GetArgument() ).GetInteger();

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.AddSpaces(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    Unquote( character_index_expression_argument, file ),
                    space_count
                    );
            }
        }
    }

    // ~~

    void RemoveFirstSpaces(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        long
            space_count;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            space_count = Unquote( GetArgument() ).GetInteger();
        }
        else
        {
            space_count = -1;
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveFirstSpaces(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    space_count
                    );
            }
        }
    }

    // ~~

    void RemoveLastSpaces(
        )
    {
        string
            line_index_expression_argument,
            post_line_index_expression_argument;
        long
            space_count;

        line_index_expression_argument = GetArgument();
        post_line_index_expression_argument = GetArgument();

        if ( HasArgument() )
        {
            space_count = Unquote( GetArgument() ).GetInteger();
        }
        else
        {
            space_count = -1;
        }

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file.RemoveLastSpaces(
                    Unquote( line_index_expression_argument, file ),
                    Unquote( post_line_index_expression_argument, file ),
                    space_count
                    );
            }
        }
    }

    // ~~

    void PushIntervals(
        )
    {
        FILE_INTERVAL
            file_interval;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file_interval = new FILE_INTERVAL();
                file_interval.LineIndex = file.LineIndex;
                file_interval.PostLineIndex = file.PostLineIndex;
                file_interval.Indentation = file.Indentation;

                file.IntervalArray ~= file_interval;
            }
        }
    }

    // ~~

    void PullIntervals(
        )
    {
        FILE_INTERVAL
            file_interval;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.IntervalArray.length > 0 )
                {
                    file_interval = file.IntervalArray[ $ - 1 ];

                    file.LineIndex = file_interval.LineIndex;
                    file.PostLineIndex = file_interval.PostLineIndex;
                    file.Indentation = file_interval.Indentation;
                }
                else
                {
                    Abort( "Missing PushIntervals" );
                }
            }
        }
    }

    // ~~

    void PopIntervals(
        )
    {
        FILE_INTERVAL
            file_interval;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.IntervalArray.length > 0 )
                {
                    file_interval = file.IntervalArray[ $ - 1 ];

                    file.LineIndex = file_interval.LineIndex;
                    file.PostLineIndex = file_interval.PostLineIndex;
                    file.Indentation = file_interval.Indentation;

                    file.IntervalArray = file.IntervalArray[ 0 .. $ - 1 ];
                }
                else
                {
                    Abort( "Missing PushIntervals" );
                }
            }
        }
    }

    // ~~

    void PushSelections(
        )
    {
        FILE_SELECTION
            file_selection;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file_selection = new FILE_SELECTION();
                file_selection.ItIsSelected = file.ItIsSelected;

                file.SelectionArray ~= file_selection;
            }
        }
    }

    // ~~

    void PullSelections(
        )
    {
        FILE_SELECTION
            file_selection;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.SelectionArray.length > 0 )
                {
                    file_selection = file.SelectionArray[ $ - 1 ];

                    file.ItIsSelected = file_selection.ItIsSelected;
                }
                else
                {
                    Abort( "Missing PushSelections" );
                }
            }
        }
    }

    // ~~

    void PopSelections(
        )
    {
        FILE_SELECTION
            file_selection;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.SelectionArray.length > 0 )
                {
                    file_selection = file.SelectionArray[ $ - 1 ];

                    file.ItIsSelected = file_selection.ItIsSelected;
                    file.SelectionArray = file.SelectionArray[ 0 .. $ - 1 ];
                }
                else
                {
                    Abort( "Missing PushSelections" );
                }
            }
        }
    }

    // ~~

    void PushMarks(
        )
    {
        FILE_MARK
            file_mark;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                file_mark = new FILE_MARK();
                file_mark.ItIsMarked = file.ItIsMarked;

                file.MarkArray ~= file_mark;
            }
        }
    }

    // ~~

    void PullMarks(
        )
    {
        FILE_MARK
            file_mark;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.MarkArray.length > 0 )
                {
                    file_mark = file.MarkArray[ $ - 1 ];

                    file.ItIsMarked = file_mark.ItIsMarked;
                }
                else
                {
                    Abort( "Missing PushMarks" );
                }
            }
        }
    }

    // ~~

    void PopMarks(
        )
    {
        FILE_MARK
            file_mark;

        foreach ( ref file; FileArray )
        {
            if ( file.IsSelected() )
            {
                if ( file.MarkArray.length > 0 )
                {
                    file_mark = file.MarkArray[ $ - 1 ];

                    file.ItIsMarked = file_mark.ItIsMarked;
                    file.MarkArray = file.MarkArray[ 0 .. $ - 1 ];
                }
                else
                {
                    Abort( "Missing PushMarks" );
                }
            }
        }
    }

    // ~~

    void Set(
        )
    {
        string
            variable_name_argument,
            assignment_operator_argument;
        string[]
            expression_argument_array;

        variable_name_argument = GetArgument();
        assignment_operator_argument = GetArgument();
        expression_argument_array = GetArgumentArray();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    AssignVariable(
                        variable_name_argument,
                        assignment_operator_argument,
                        expression_argument_array,
                        file
                        );
                }
            }
        }
        else
        {
            AssignVariable(
                variable_name_argument,
                assignment_operator_argument,
                expression_argument_array
                );
        }
    }

    // ~~

    void Repeat(
        )
    {
        long
            label_line_index;
        string[]
            condition_argument_array;

        label_line_index = GetLabelLineIndex( Unquote( GetArgument() ) );

        if ( HasArgument() )
        {
            condition_argument_array = GetArgumentArray();

            if ( FilesAreIterated )
            {
                foreach( ref file; FileArray )
                {
                    if ( file.IsSelected()
                         && GetBooleanValue( condition_argument_array, file ) )
                    {
                        LineIndex = label_line_index;

                        break;
                    }
                }
            }
            else
            {
                if ( GetBooleanValue( condition_argument_array ) )
                {
                    LineIndex = label_line_index;
                }
            }
        }
        else
        {
            if ( FilesAreIterated )
            {
                foreach( ref file; FileArray )
                {
                    if ( file.IsSelected() )
                    {
                        LineIndex = label_line_index;

                        break;
                    }
                }
            }
            else
            {
                LineIndex = label_line_index;
            }
        }
    }

    // ~~

    void Call(
        )
    {
        long
            label_line_index;
        string
            label;
        CALL
            call;

        label = Unquote( GetArgument() );
        label_line_index = GetLabelLineIndex( label );

        if ( FilesAreIterated )
        {
            foreach( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    call = new CALL();
                    call.ArgumentArray = Unquote( GetArgumentArray(), file );
                    call.ReturnLineIndex = LineIndex;

                    CallArray ~= call;

                    LineIndex = label_line_index;

                    while ( ExecuteLine() > 0 )
                    {
                        ++LineIndex;
                    }
                }
            }
        }
        else
        {
            call = new CALL();
            call.ArgumentArray = Unquote( GetArgumentArray() );
            call.ReturnLineIndex = LineIndex;

            CallArray ~= call;

            LineIndex = label_line_index;

            while ( ExecuteLine() > 0 )
            {
                ++LineIndex;
            }
        }
    }

    // ~~

    void Return(
        )
    {
        CALL
            call;

        if ( HasArgument() )
        {
            Result = GetValue( GetArgumentArray() );
        }
        else
        {
            Result = "";
        }

        if ( CallArray.length > 0 )
        {
            call = CallArray[ $ - 1 ];

            LineIndex = call.ReturnLineIndex;

            CallArray = CallArray[ 0 .. $ - 1 ];
        }
        else
        {
            Abort( "Missing function call" );
        }
    }

    // ~~

    void Exit(
        )
    {
        exit( 0 );
    }

    // ~~

    void Abort(
        )
    {
        Abort( GetValue( GetArgumentArray() ) );
    }

    // ~~

    void Assert(
        )
    {
        string[]
            expression_argument_array;

        expression_argument_array = GetArgumentArray();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    if ( !GetBooleanValue( expression_argument_array, file ) )
                    {
                        Abort( "Invalid assertion : " ~ expression_argument_array.join( ' ' ) );
                    }
                }
            }
        }
        else
        {
            if ( !GetBooleanValue( expression_argument_array ) )
            {
                Abort( "Invalid assertion : " ~ expression_argument_array.join( ' ' ) );
            }
        }
    }

    // ~~

    void Include(
        )
    {
        long
            line_index;
        SCRIPT
            script;

        line_index = LineIndex;

        script = new SCRIPT();
        script.Load( Unquote( GetArgument() ) );

        LineArray = LineArray[ 0 .. line_index ] ~ script.LineArray ~ LineArray[ line_index + 2 .. $ ];
        LineIndexArray = LineIndexArray[ 0 .. line_index ] ~ script.LineIndexArray ~ LineIndexArray[ line_index + 2 .. $ ];
        FilePathArray = FilePathArray[ 0 .. line_index ] ~ script.FilePathArray ~ FilePathArray[ line_index + 2 .. $ ];

        LineIndex = line_index - 1;
    }

    // ~~

    void Execute(
        )
    {
        string
            script_file_path_argument;
        string[]
            script_argument_array;
        SCRIPT
            old_script;

        script_file_path_argument = GetArgument();
        script_argument_array = GetArgumentArray();

        if ( FilesAreIterated )
        {
            foreach ( ref file; FileArray )
            {
                if ( file.IsSelected() )
                {
                    old_script = Script;

                    Script = new SCRIPT();
                    Script.ExecuteScript(
                        Unquote( script_file_path_argument, file ),
                        Unquote( script_argument_array, file )
                        );

                    Script = old_script;
                }
            }
        }
        else
        {
            old_script = Script;

            Script = new SCRIPT();
            Script.ExecuteScript(
                Unquote( script_file_path_argument ),
                Unquote( script_argument_array )
                );

            Script = old_script;
        }
    }

    // ~~

    void Do(
        )
    {
        string[]
            command_argument_array;

        command_argument_array = GetArgumentArray();

        if ( command_argument_array.length >= 1 )
        {
            if ( FilesAreIterated )
            {
                foreach ( ref file; FileArray )
                {
                    if ( file.IsSelected() )
                    {
                        auto result = execute( Unquote( command_argument_array, file ) );

                        if ( result.status != 0 )
                        {
                            Abort( "Invalid command : " ~ command_argument_array.to!string() );
                        }
                    }
                }
            }
            else
            {
                auto result = execute( Unquote( command_argument_array ) );

                if ( result.status != 0 )
                {
                    Abort( "Invalid command : " ~ command_argument_array.to!string() );
                }
            }
        }
        else
        {
            Abort( "Invalid command : " ~ command_argument_array.to!string() );
        }
    }

    // ~~

    long ExecuteLine(
        )
    {
        char
            character;
        string
            command;

        if ( LineIndex < LineArray.length )
        {
            command = LineArray[ LineIndex ].stripRight();

            if ( command.length > 0
                 && !command.startsWith( "#" )
                 && !command.startsWith( ":" ) )
            {
                if ( VerboseOptionIsEnabled )
                {
                    writeln( FilePathArray[ LineIndex ], "[", LineIndexArray[ LineIndex ], "] ", command );
                }

                if ( command.indexOf( ' ' ) >= 0 )
                {
                    Abort( "Invalid command : " ~ command );
                }

                FilesAreIterated = true;

                FilesAreSelected = false;
                FilesMustBeSelected = false;
                FilesMustNotBeSelected = false;

                FilesAreMarked = false;
                FilesMustBeMarked = false;
                FilesMustNotBeMarked = false;

                FilesMustHaveLineInterval = false;

                while ( command.length > 0 )
                {
                    character = command[ $ - 1 ];

                    if ( character == '!' )
                    {
                        FilesAreIterated = false;
                    }
                    else if ( character == '%' )
                    {
                        FilesAreSelected = true;
                    }
                    else if ( character == '^' )
                    {
                        FilesMustBeSelected = true;
                    }
                    else if ( character == '~' )
                    {
                        FilesMustNotBeSelected = true;
                    }
                    else if ( character == '#' )
                    {
                        FilesAreMarked = true;
                    }
                    else if ( character == '?' )
                    {
                        FilesMustBeMarked = true;
                    }
                    else if ( character == ':' )
                    {
                        FilesMustNotBeMarked = true;
                    }
                    else if ( character == '*' )
                    {
                        FilesMustHaveLineInterval = true;
                    }
                    else
                    {
                        break;
                    }

                    command = command[ 0 .. $ - 1 ];
                }

                if ( command == "EnableQuotation" )
                {
                    EnableQuotation();
                }
                else if ( command == "DisableQuotation" )
                {
                    DisableQuotation();
                }
                else if ( command == "CheckFirstSpaces" )
                {
                    CheckFirstSpaces();
                }
                else if ( command == "IgnoreFirstSpaces" )
                {
                    IgnoreFirstSpaces();
                }
                else if ( command == "CheckInnerSpaces" )
                {
                    CheckInnerSpaces();
                }
                else if ( command == "IgnoreInnerSpaces" )
                {
                    IgnoreInnerSpaces();
                }
                else if ( command == "CheckLastSpaces" )
                {
                    CheckLastSpaces();
                }
                else if ( command == "IgnoreLastSpaces" )
                {
                    IgnoreLastSpaces();
                }
                else if ( command == "CheckSideSpaces" )
                {
                    CheckSideSpaces();
                }
                else if ( command == "IgnoreSideSpaces" )
                {
                    IgnoreSideSpaces();
                }
                else if ( command == "SetTabulationSpaceCount" )
                {
                    SetTabulationSpaceCount();
                }
                else if ( command == "SetFolder" )
                {
                    SetFolder();
                }
                else if ( command == "SetInputFolder" )
                {
                    SetInputFolder();
                }
                else if ( command == "SetOutputFolder" )
                {
                    SetOutputFolder();
                }
                else if ( command == "RemoveFiles" )
                {
                    RemoveFiles();
                }
                else if ( command == "MoveFiles" )
                {
                    MoveFiles();
                }
                else if ( command == "CopyFiles" )
                {
                    CopyFiles();
                }
                else if ( command == "ReadFiles" )
                {
                    ReadFiles();
                }
                else if ( command == "IncludeFiles" )
                {
                    IncludeFiles();
                }
                else if ( command == "ExcludeFiles" )
                {
                    ExcludeFiles();
                }
                else if ( command == "CreateFiles" )
                {
                    CreateFiles();
                }
                else if ( command == "CreateFolders" )
                {
                    CreateFolders();
                }
                else if ( command == "WriteFiles" )
                {
                    WriteFiles();
                }
                else if ( command == "Print" )
                {
                    Print();
                }
                else if ( command == "PrintLines" )
                {
                    PrintLines();
                }
                else if ( command == "PrintRanges" )
                {
                    PrintRanges();
                }
                else if ( command == "PrintIntervals" )
                {
                    PrintIntervals();
                }
                else if ( command == "PrintSelectedLines" )
                {
                    PrintSelectedLines();
                }
                else if ( command == "PrintChangedLines" )
                {
                    PrintChangedLines();
                }
                else if ( command == "PrintArguments" )
                {
                    PrintArguments();
                }
                else if ( command == "PrintVariables" )
                {
                    PrintVariables();
                }
                else if ( command == "SetFilePath" )
                {
                    SetFilePath();
                }
                else if ( command == "SetLineIndex" )
                {
                    SetLineIndex();
                }
                else if ( command == "SetLineCount" )
                {
                    SetLineCount();
                }
                else if ( command == "SetLineRange" )
                {
                    SetLineRange();
                }
                else if ( command == "SetPostLineIndex" )
                {
                    SetPostLineIndex();
                }
                else if ( command == "SetLineInterval" )
                {
                    SetLineInterval();
                }
                else if ( command == "ReplaceTabulations" )
                {
                    ReplaceTabulations();
                }
                else if ( command == "ReplaceSpaces" )
                {
                    ReplaceSpaces();
                }
                else if ( command == "ReplaceText" )
                {
                    ReplaceText( false, false, false );
                }
                else if ( command == "ReplaceIdentifier" )
                {
                    ReplaceText( false, false, true );
                }
                else if ( command == "ReplaceUnquotedText" )
                {
                    ReplaceText( true, false, false );
                }
                else if ( command == "ReplaceUnquotedIdentifier" )
                {
                    ReplaceText( true, false, true );
                }
                else if ( command == "ReplaceQuotedText" )
                {
                    ReplaceText( false, true, false );
                }
                else if ( command == "ReplaceQuotedIdentifier" )
                {
                    ReplaceText( false, true, true );
                }
                else if ( command == "ReplaceExpression" )
                {
                    ReplaceExpression();
                }
                else if ( command == "SelectFiles" )
                {
                    SelectFiles();
                }
                else if ( command == "IgnoreFiles" )
                {
                    IgnoreFiles();
                }
                else if ( command == "MarkFiles" )
                {
                    MarkFiles();
                }
                else if ( command == "UnmarkFiles" )
                {
                    UnmarkFiles();
                }
                else if ( command == "FindText" )
                {
                    FindText();
                }
                else if ( command == "ReachText" )
                {
                    ReachText();
                }
                else if ( command == "FindLines" )
                {
                    FindLines();
                }
                else if ( command == "ReachLines" )
                {
                    ReachLines();
                }
                else if ( command == "FindPrefixes" )
                {
                    FindPrefixes();
                }
                else if ( command == "ReachPrefixes" )
                {
                    ReachPrefixes();
                }
                else if ( command == "FindSuffixes" )
                {
                    FindSuffixes();
                }
                else if ( command == "ReachSuffixes" )
                {
                    ReachSuffixes();
                }
                else if ( command == "FindExpressions" )
                {
                    FindExpressions();
                }
                else if ( command == "ReachExpressions" )
                {
                    ReachExpressions();
                }
                else if ( command == "InsertLines" )
                {
                    InsertLines();
                }
                else if ( command == "AddLines" )
                {
                    AddLines();
                }
                else if ( command == "AddEmptyLines" )
                {
                    AddEmptyLines();
                }
                else if ( command == "RemoveLines" )
                {
                    RemoveLines();
                }
                else if ( command == "RemoveFirstEmptyLines" )
                {
                    RemoveFirstEmptyLines();
                }
                else if ( command == "RemoveLastEmptyLines" )
                {
                    RemoveLastEmptyLines();
                }
                else if ( command == "RemoveEmptyLines" )
                {
                    RemoveEmptyLines();
                }
                else if ( command == "RemoveDoubleEmptyLines" )
                {
                    RemoveDoubleEmptyLines();
                }
                else if ( command == "SkipLines" )
                {
                    SkipLines();
                }
                else if ( command == "SetLines" )
                {
                    SetLines();
                }
                else if ( command == "CopyLines" )
                {
                    CopyLines();
                }
                else if ( command == "CutLines" )
                {
                    CutLines();
                }
                else if ( command == "PasteLines" )
                {
                    PasteLines();
                }
                else if ( command == "AddText" )
                {
                    AddText();
                }
                else if ( command == "RemovePrefix" )
                {
                    RemovePrefix();
                }
                else if ( command == "RemoveSuffix" )
                {
                    RemoveSuffix();
                }
                else if ( command == "RemoveText" )
                {
                    RemoveText();
                }
                else if ( command == "RemoveSideText" )
                {
                    RemoveSideText();
                }
                else if ( command == "AddSpaces" )
                {
                    AddSpaces();
                }
                else if ( command == "RemoveFirstSpaces" )
                {
                    RemoveFirstSpaces();
                }
                else if ( command == "RemoveLastSpaces" )
                {
                    RemoveLastSpaces();
                }
                else if ( command == "PushIntervals" )
                {
                    PushIntervals();
                }
                else if ( command == "PullIntervals" )
                {
                    PullIntervals();
                }
                else if ( command == "PopIntervals" )
                {
                    PopIntervals();
                }
                else if ( command == "PushSelections" )
                {
                    PushSelections();
                }
                else if ( command == "PullSelections" )
                {
                    PullSelections();
                }
                else if ( command == "PopSelections" )
                {
                    PopSelections();
                }
                else if ( command == "PushMarks" )
                {
                    PushMarks();
                }
                else if ( command == "PullMarks" )
                {
                    PullMarks();
                }
                else if ( command == "PopMarks" )
                {
                    PopMarks();
                }
                else if ( command == "Set" )
                {
                    Set();
                }
                else if ( command == "Set" )
                {
                    Set();
                }
                else if ( command == "Repeat" )
                {
                    Repeat();
                }
                else if ( command == "Call" )
                {
                    Call();
                }
                else if ( command == "Return" )
                {
                    Return();

                    return 0;
                }
                else if ( command == "Exit" )
                {
                    Exit();
                }
                else if ( command == "Abort" )
                {
                    Abort();
                }
                else if ( command == "Assert" )
                {
                    Assert();
                }
                else if ( command == "Include" )
                {
                    Include();
                }
                else if ( command == "Execute" )
                {
                    Execute();
                }
                else if ( command == "Do" )
                {
                    Do();
                }
                else
                {
                    Abort( "Invalid command : " ~ command );
                }
            }

            return 1;
        }

        return -1;
    }

    // ~~

    void ExecuteScript(
        string file_path,
        string[] argument_array
        )
    {

        FilePath = file_path;
        ArgumentArray = argument_array;

        QuotationIsEnabled = true;
        FirstSpacesAreChecked = true;
        InnerSpacesAreChecked = true;
        LastSpacesAreChecked = true;
        TabulationSpaceCount = 4;

        Load( file_path );

        LineIndex = 0;

        while ( ExecuteLine() >= 0 )
        {
            ++LineIndex;
        }
    }
}

// -- VARIABLES

bool
    PreviewOptionIsEnabled,
    VerboseOptionIsEnabled;
SCRIPT
    Script;

// -- FUNCTIONS

void Abort(
    string message
    )
{
    writeln( "*** ERROR : ", message );

    exit( -1 );
}

// ~~

bool IsNatural(
    string text
    )
{
    if ( text.length > 0 )
    {
        foreach ( character; text )
        {
            if ( character < '0'
                 || character > '9' )
            {
                return false;
            }
        }

        return true;
    }

    return false;
}

// ~~

bool IsInteger(
    string text
    )
{
    if ( text.length > 0
         && text[ 0 ] == '-' )
    {
        text = text[ 1 .. $ ];
    }

    return text.IsNatural();
}

// ~~

long GetInteger(
    string text
    )
{
    if ( text.IsInteger() )
    {
        return text.to!long();
    }

    Abort( "Invalid integer : " ~ text );

    return 0;
}

// ~~

bool IsIdentifierCharacter(
    char character
    )
{
    return
        ( character >= 'a' && character <= 'z' )
        || ( character >= 'A' && character <= 'Z' )
        || ( character >= '0' && character <= '9' )
        || character == '_';
}

// ~~

bool IsIdentifier(
    string text
    )
{
    if ( text.length > 0 )
    {
        if ( text[ 0 ] >= '0'
             && text[ 0 ] <= '9' )
        {
            return false;
        }

        foreach ( character; text )
        {
            if ( !IsIdentifierCharacter( character ) )
            {
                return false;
            }
        }

        return true;
    }

    return false;
}

// ~~

bool IsQuoteCharacter(
    char character
    )
{
    return
        character == '\''
        || character == '\"'
        || character == '`';
}

// ~~

bool IsLowerCaseLetter(
    dchar character
    )
{
    return
        ( character >= 'a' && character <= 'z' )
        || character == 'à'
        || character == 'â'
        || character == 'é'
        || character == 'è'
        || character == 'ê'
        || character == 'ë'
        || character == 'î'
        || character == 'ï'
        || character == 'ô'
        || character == 'ö'
        || character == 'û'
        || character == 'ü'
        || character == 'ç'
        || character == 'ñ';
}

// ~~

bool IsUpperCaseLetter(
    dchar character
    )
{
    return
        ( character >= 'A' && character <= 'Z' )
        || character == 'À'
        || character == 'Â'
        || character == 'É'
        || character == 'È'
        || character == 'Ê'
        || character == 'Ë'
        || character == 'Î'
        || character == 'Ï'
        || character == 'Ô'
        || character == 'Ö'
        || character == 'Û'
        || character == 'Ü'
        || character == 'Ñ';
}

// ~~

bool IsSetter(
    dchar character
    )
{
    return
        IsLowerCaseLetter( character )
        || IsUpperCaseLetter( character );
}

// ~~

bool IsDigit(
    dchar character
    )
{
    return character >= '0' && character <= '9';
}

// ~~

dchar GetLowerCaseCharacter(
    dchar character
    )
{
    if ( character >= 'A' && character <= 'Z' )
    {
        return 'a' + ( character - 'A' );
    }
    else
    {
        switch ( character )
        {
            case 'À' : return 'à';
            case 'Â' : return 'â';
            case 'É' : return 'é';
            case 'È' : return 'è';
            case 'Ê' : return 'ê';
            case 'Ë' : return 'ë';
            case 'Î' : return 'î';
            case 'Ï' : return 'ï';
            case 'Ô' : return 'ô';
            case 'Ö' : return 'ö';
            case 'Û' : return 'û';
            case 'Ü' : return 'ü';
            case 'Ñ' : return 'ñ';

            default : return character;
        }
    }
}


// ~~

dchar GetUpperCaseCharacter(
    dchar character
    )
{
    if ( character >= 'a' && character <= 'z' )
    {
        return 'A' + ( character - 'a' );
    }
    else
    {
        switch ( character )
        {
            case 'à' : return 'À';
            case 'â' : return 'Â';
            case 'é' : return 'É';
            case 'è' : return 'È';
            case 'ê' : return 'Ê';
            case 'ë' : return 'Ë';
            case 'î' : return 'Î';
            case 'ï' : return 'Ï';
            case 'ô' : return 'Ô';
            case 'ö' : return 'Ö';
            case 'û' : return 'Û';
            case 'ü' : return 'Ü';
            case 'ç' : return 'C';
            case 'ñ' : return 'Ñ';

            default : return character;
        }
    }
}

// ~~

string GetLowerCaseText(
    string text
    )
{
    string
        lower_case_text;

    foreach ( dchar character; text )
    {
        lower_case_text ~= GetLowerCaseCharacter( character );
    }

    return lower_case_text;
}

// ~~

string GetUpperCaseText(
    string text
    )
{
    string
        upper_case_text;

    foreach ( dchar character; text )
    {
        upper_case_text ~= GetUpperCaseCharacter( character );
    }

    return upper_case_text;
}

// ~~

string GetMinorCaseText(
    string text
    )
{
    if ( text.length >= 2 )
    {
        return text[ 0 .. 1 ].GetLowerCaseText() ~ text[ 1 .. $ ];
    }
    else
    {
        return text.GetLowerCaseText();
    }
}

// ~~

string GetMajorCaseText(
    string text
    )
{
    if ( text.length >= 2 )
    {
        return text[ 0 .. 1 ].GetUpperCaseText() ~ text[ 1 .. $ ];
    }
    else
    {
        return text.GetUpperCaseText();
    }
}

// ~~

string GetCamelCaseText(
    string text
    )
{
    dchar
        prior_character;
    string
        camel_case_text;

    camel_case_text = "";

    prior_character = 0;

    foreach ( dchar character; text )
    {
        if ( character.IsLowerCaseLetter()
             && !prior_character.IsSetter() )
        {
            camel_case_text ~= character.GetUpperCaseCharacter();
        }
        else
        {
            camel_case_text ~= character;
        }

        prior_character = character;
    }

    return camel_case_text;
}

// ~~

string GetSnakeCaseText(
    string text
    )
{
    dchar
        prior_character;
    string
        snake_case_text;

    snake_case_text = "";
    prior_character = 0;

    foreach ( dchar character; text )
    {
        if ( ( prior_character.IsLowerCaseLetter()
               && ( character.IsUpperCaseLetter()
                    || character.IsDigit() ) )
             || ( prior_character.IsDigit()
                  && ( character.IsLowerCaseLetter()
                       || character.IsUpperCaseLetter() ) ) )
        {
            snake_case_text ~= '_';
        }

        snake_case_text ~= character;

        prior_character = character;
    }

    return snake_case_text;
}

// ~~

string ReplaceTabulations(
    string line,
    long tabulation_space_count
    )
{
    char
        character;
    long
        character_index,
        line_character_index;
    string
        replaced_line;

    if ( tabulation_space_count > 0
         && line.indexOf( '\t' ) >= 0 )
    {
        replaced_line = "";

        line_character_index = 0;

        for ( character_index = 0;
              character_index < line.length;
              ++character_index )
        {
            character = line[ character_index ];

            if ( character == '\t' )
            {
                do
                {
                    replaced_line ~= ' ';

                    ++line_character_index;
                }
                while ( ( line_character_index % tabulation_space_count ) != 0 );
            }
            else
            {
                replaced_line ~= character;

                ++line_character_index;
            }
        }

        return replaced_line;
    }
    else
    {
        return line;
    }
}

// ~~

string ReplaceSpaces(
    string line,
    long tabulation_space_count
    )
{
    char
        character;
    long
        character_index;
    string
        replaced_line,
        tabulation_text;

    if ( tabulation_space_count > 0 )
    {
        tabulation_text = "        "[ 0 .. tabulation_space_count ];

        replaced_line = "";

        character_index = 0;

        while ( character_index < line.length )
        {
            character = line[ character_index ];

            if ( character == ' '
                 && ( replaced_line.length == 0
                      || replaced_line[ $ - 1 ] == '\t' )
                 && character_index + tabulation_space_count <= line.length
                 && line[ character_index .. character_index + tabulation_space_count ] == tabulation_text )
            {
                replaced_line ~= '\t';

                character_index += tabulation_space_count;
            }
            else
            {
                replaced_line ~= character;

                ++character_index;
            }
        }

        return replaced_line;
    }
    else
    {
        return line;
    }
}

// ~~

string ReplaceText(
    string text,
    string old_text,
    string new_text,
    bool it_must_be_unquoted,
    bool it_must_be_quoted,
    bool it_must_be_in_identifier
    )
{
    bool
        it_is_in_identifier,
        it_is_quoted;
    char
        character,
        prior_character,
        quote_character;
    long
        character_index;

    if ( old_text.length > 0
         && text.length >= old_text.length )
    {
        quote_character = 0;
        it_is_quoted = false;
        it_is_in_identifier = false;
        prior_character = 0;
        character_index = 0;

        while ( character_index + old_text.length <= text.length )
        {
            if ( text[ character_index .. character_index + old_text.length ] == old_text )
            {
                it_is_in_identifier
                    = ( it_must_be_in_identifier
                        && !IsIdentifierCharacter( prior_character )
                        && ( character_index + old_text.length >= text.length
                             || !IsIdentifierCharacter( text[ character_index + old_text.length ] ) ) );

                if ( ( !it_must_be_unquoted || !it_is_quoted )
                     && ( !it_must_be_quoted || it_is_quoted )
                     && ( !it_must_be_in_identifier || it_is_in_identifier ) )
                {
                    prior_character = text[ character_index + old_text.length.to!long() - 1 ];

                    text
                        = text[ 0 .. character_index ]
                          ~ new_text
                          ~ text[ character_index + old_text.length .. $ ];

                    character_index += new_text.length;

                    continue;
                }
            }

            character = text[ character_index ];
            prior_character = character;

            if ( it_is_quoted )
            {
                if ( character == quote_character )
                {
                    it_is_quoted = false;
                }
                else if ( character == '\\' )
                {
                    prior_character = character;

                    character_index += 2;

                    continue;
                }
            }
            else
            {
                if ( ( it_must_be_unquoted || it_must_be_quoted )
                     && IsQuoteCharacter( character ) )
                {
                    it_is_quoted = true;

                    quote_character = character;
                }
            }

            prior_character = text[ character_index ];

            ++character_index;
        }
    }

    return text;
}

// ~~

string GetFolderPath(
    string file_path
    )
{
    return file_path[ 0 .. file_path.lastIndexOf( '/' ) + 1 ];
}

// ~~

string GetFileName(
    string file_path
    )
{
    return file_path[ file_path.lastIndexOf( '/' ) + 1 .. $ ];
}

// ~~

void SplitFilePath(
    string file_path,
    ref string folder_path,
    ref string file_name
    )
{
    long
        folder_path_character_count;

    folder_path_character_count = file_path.lastIndexOf( '/' ) + 1;

    folder_path = file_path[ 0 .. folder_path_character_count ];
    file_name = file_path[ folder_path_character_count .. $ ];
}

// ~~

void SplitFileName(
    string file_name,
    ref string base_name,
    ref string file_extension
    )
{
    long
        dot_character_index;

    dot_character_index = file_name.lastIndexOf( '.' );

    if ( dot_character_index >= 0 )
    {
        base_name = file_name[ 0 .. dot_character_index ];
        file_extension = file_name[ dot_character_index .. $ ];
    }
    else
    {
        base_name = file_name;
        file_extension = "";
    }
}

// ~~

void SplitFilePathFilter(
    string file_path_filter,
    ref string folder_path,
    ref string file_name_filter,
    ref SpanMode span_mode
    )
{
    long
        folder_path_character_count;
    string
        file_name;

    folder_path_character_count = file_path_filter.lastIndexOf( '/' ) + 1;

    folder_path = file_path_filter[ 0 .. folder_path_character_count ];
    file_name_filter = file_path_filter[ folder_path_character_count .. $ ];

    if ( folder_path.endsWith( "//" ) )
    {
        folder_path = folder_path[ 0 .. $ - 1 ];

        span_mode = SpanMode.depth;
    }
    else
    {
        span_mode = SpanMode.shallow;
    }
}

// ~~

string[] Split(
    string text
    )
{
    if ( text.length == 0 )
    {
        return [ "" ];
    }
    else
    {
        return text.split( '\n' );
    }
}

// ~~

string Join(
    string[] line_array
    )
{
    return line_array.join( '\n' );
}

// ~~

void main(
    string[] argument_array
    )
{
    string
        option;

    VerboseOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;

    argument_array = argument_array[ 1 .. $ ];

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--verbose" )
        {
            VerboseOptionIsEnabled = true;
        }
        else if ( option == "--preview" )
        {
            PreviewOptionIsEnabled = true;
        }
        else
        {
            Abort( "Invalid option : " ~ option );
        }
    }

    if ( argument_array.length >= 1 )
    {
        Script = new SCRIPT();
        Script.ExecuteScript( argument_array[ 0 ], argument_array[ 1 .. $ ] );
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    batched [options] script_file.batched" );
        writeln( "Options :" );
        writeln( "    --dump line_count" );
        writeln( "    --verbose" );
        writeln( "    --preview" );
        writeln( "Commands :" );
        writeln( "    :label" );
        writeln( "    EnableQuotation" );
        writeln( "    DisableQuotation" );
        writeln( "    CheckFirstSpaces" );
        writeln( "    IgnoreFirstSpaces" );
        writeln( "    CheckLastSpaces" );
        writeln( "    IgnoreLastSpaces" );
        writeln( "    CheckInnerSpaces" );
        writeln( "    IgnoreInnerSpaces" );
        writeln( "    SetTabulationSpaceCount tabulation_space_count" );
        writeln( "    SetFolder INPUT_OUTPUT_FOLDER/" );
        writeln( "    SetInputFolder INPUT_FOLDER/" );
        writeln( "    SetOutputFolder OUTPUT_FOLDER/" );
        writeln( "    RemoveFiles[!] {file_paths}" );
        writeln( "    MoveFiles[!] source_file_path target_file_path" );
        writeln( "    CopyFiles[!] source_file_path target_file_path" );
        writeln( "    ReadFiles {input_file_path_filters}" );
        writeln( "    IncludeFiles {input_file_path_filters}" );
        writeln( "    ExcludeFiles [{input_file_path_filters}]" );
        writeln( "    CreateFiles {input_file_paths}" );
        writeln( "    CreateFolders {folder_paths}" );
        writeln( "    WriteFiles" );
        writeln( "    Print[!] expression" );
        writeln( "    PrintRanges" );
        writeln( "    PrintIntervals" );
        writeln( "    PrintLines [line_index post_line_index]" );
        writeln( "    PrintSelectedLines" );
        writeln( "    PrintChangedLines [near_line_count]" );
        writeln( "    PrintArguments" );
        writeln( "    PrintVariables[!]" );
        writeln( "    SetFilePath file_path" );
        writeln( "    SetLineIndex line_index" );
        writeln( "    SetLineCount line_count" );
        writeln( "    SetLineRange line_index line_count" );
        writeln( "    SetPostLineIndex post_line_index" );
        writeln( "    SetLineInterval line_index post_line_index" );
        writeln( "    ReplaceTabulations line_index post_line_index" );
        writeln( "    ReplaceSpaces line_index post_line_index" );
        writeln( "    ReplaceText line_index post_line_index old_text new_text" );
        writeln( "    ReplaceIdentifier line_index post_line_index old_text new_text" );
        writeln( "    ReplaceUnquotedText line_index post_line_index old_text new_text" );
        writeln( "    ReplaceUnquotedIdentifier line_index post_line_index old_text new_text" );
        writeln( "    ReplaceQuotedText line_index post_line_index old_text new_text" );
        writeln( "    ReplaceQuotedIdentifier line_index post_line_index old_text new_text" );
        writeln( "    ReplaceExpression line_index post_line_index old_expression new_text" );
        writeln( "    SelectFiles {input_file_path_filters}" );
        writeln( "    IgnoreFiles {input_file_path_filters}" );
        writeln( "    MarkFiles {input_file_path_filters}" );
        writeln( "    UnmarkFiles {input_file_path_filters}" );
        writeln( "    FindText line_index post_line_index text" );
        writeln( "    ReachText post_line_index text" );
        writeln( "    FindLines line_index post_line_index {lines}" );
        writeln( "    ReachLines post_line_index {lines}" );
        writeln( "    FindPrefixes line_index post_line_index {prefixes}" );
        writeln( "    ReachPrefixes post_line_index {prefixes}" );
        writeln( "    FindSuffixes line_index post_line_index {suffixes}" );
        writeln( "    ReachSuffixes post_line_index {suffixes}" );
        writeln( "    FindExpressions line_index post_line_index {expressions}" );
        writeln( "    ReachExpressions post_line_index {expressions}" );
        writeln( "    InsertLines line_index character_index {lines}" );
        writeln( "    AddLines line_index {lines}" );
        writeln( "    AddEmptyLines line_index line_count" );
        writeln( "    RemoveLines line_index post_line_index" );
        writeln( "    RemoveFirstEmptyLines line_index post_line_index [line_count]" );
        writeln( "    RemoveLastEmptyLines line_index post_line_index [line_count]" );
        writeln( "    RemoveEmptyLines line_index post_line_index" );
        writeln( "    RemoveDoubleEmptyLines line_index post_line_index" );
        writeln( "    SkipLines" );
        writeln( "    SetLines line_index post_line_index {lines}" );
        writeln( "    CopyLines buffer_letter line_index post_line_index [character_index post_character_index]" );
        writeln( "    CutLines buffer_letter line_index post_line_index [character_index post_character_index]" );
        writeln( "    PasteLines buffer_letter line_index [character_index]" );
        writeln( "    AddText line_index post_line_index character_index text" );
        writeln( "    RemovePrefix line_index post_line_index prefix" );
        writeln( "    RemoveSuffix line_index post_line_index suffix" );
        writeln( "    RemoveText line_index post_line_index character_index post_character_index" );
        writeln( "    RemoveSideText line_index post_line_index character_index post_character_index" );
        writeln( "    AddSpaces line_index post_line_index character_index space_count" );
        writeln( "    RemoveFirstSpaces line_index post_line_index [space_count]" );
        writeln( "    RemoveLastSpaces line_index post_line_index [space_count]" );
        writeln( "    PushIntervals" );
        writeln( "    PullIntervals" );
        writeln( "    PopIntervals" );
        writeln( "    PushSelections" );
        writeln( "    PullSelections" );
        writeln( "    PopSelections" );
        writeln( "    PushMarks" );
        writeln( "    PullMarks" );
        writeln( "    PopMarks" );
        writeln( "    Set[!] variable_name assignment_operator expression" );
        writeln( "    Repeat[!] label [condition]" );
        writeln( "    Call[!] label {arguments}" );
        writeln( "    Return [expression]" );
        writeln( "    Exit" );
        writeln( "    Abort message" );
        writeln( "    Assert[!] condition" );
        writeln( "    Include script_file_path" );
        writeln( "    Execute[!] script_file_path {arguments}" );
        writeln( "    Do[!] shell_command {arguments}");
        writeln( "Examples :" );
        writeln( "    batched --dump 3 --verbose --print --preview script_file.batched" );
        writeln( "    batched script_file.batched" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
