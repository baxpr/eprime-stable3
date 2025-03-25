#!/usr/bin/env python3
#
# Read E-Prime text files and convert to CSV

import argparse
import re
import pandas
import os

    
def main():

    # Parse arguments
    parser = argparse.ArgumentParser(description='Parse E-Prime text output and create CSV')
    parser.add_argument('-o', '--outcsv', help='File to store the output CSV')
    parser.add_argument('eprime_txt', help='E-Prime txt file', metavar='EPRIME_TXT')
    args = parser.parse_args()

    # Generate output CSV path+filename
    if args.outcsv is None:
        # https://stackoverflow.com/a/59082116
        out_csv = '.csv'.join(args.eprime_txt.rsplit('.txt',1))
    else:
        out_csv = args.outcsv

    # Read entire file into a string, eliminating nulls
    #with open(args.eprime_txt) as f:
    print(f'Converting {args.eprime_txt}')
    with open(args.eprime_txt,encoding='utf-16') as f:
        txt = f.read().replace(u'\x00','')

    # Pull out header, main body. No special treatment for carriage returns (DOTALL)
    expr_main = re.compile(
        '\*\*\* Header Start \*\*\*(?P<hdr>.*)\*\*\* Header End \*\*\*'
        '(?P<body>.*)'
        ,re.DOTALL)
    match_main = re.match(expr_main,txt)

    # Parse header into fields and values
    expr_fields = re.compile(
        '^\t*(?P<field>.*?)\: (?P<value>.*)$'
        ,re.MULTILINE)
    parsed_hdr = re.findall(expr_fields,match_main.group('hdr'))
    parsed_hdr.append(('Level','0'))

    # Pull out log frames. Can't be greedy if we want to separate frames, so lots of *?
    expr_frame = re.compile(
        '\t*?Level\: (?P<level>[0-9]*?)[\n\r\t]*?'
        '\*\*\* LogFrame Start \*\*\*[\n\r\t]*?'
        '(?P<frame>.*?)[\n\r\t]*?'
        '\*\*\* LogFrame End \*\*\*'
        ,re.DOTALL)
    match_frame = re.findall(expr_frame,match_main.group('body'))
    print(f'Found {len(match_frame)} log frames to convert')

    # Parse log frames into fields and values, reorganize into data frame
    parsed_frames = pandas.DataFrame(dict(parsed_hdr),index=[0])
    for frame in match_frame:
        parsed_frame = re.findall(expr_fields,frame[1])
        parsed_frame.append(('Level',frame[0]))
        parsed_frame = pandas.DataFrame(dict(parsed_frame),index=[0])
        #parsed_frames = parsed_frames.append(parsed_frame)
        parsed_frames = pandas.concat([parsed_frames, parsed_frame], ignore_index=True)

    # Write to CSV
    print(f'Saving to {out_csv}')
    parsed_frames.to_csv(out_csv)



if __name__ == "__main__":
    main()
    

