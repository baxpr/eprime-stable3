#!/usr/bin/env bash
#
# Primary entrypoint for our pipeline. This just parses the command line 
# arguments, exporting them in environment variables for easy access
# by other shell scripts later. Then it calls the rest of the pipeline.

echo Running $(basename "${BASH_SOURCE}")

# Initialize defaults
export timeoverride=0
export renumoverride=0
export out_dir=/OUTPUTS
fmri_dcm_str=

# Parse input options
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        
        --eprime_txt)
            export eprime_txt="$2"; shift; shift ;;

        --fmri_dcm)
            export fmri_dcm="$2"
            fmri_dcm_str="fmri_dcm ${fmri_dcm}"
            shift; shift ;;

        --timeoverride)
            export timeoverride="$2"; shift; shift ;;

        --renumoverride)
            export renumoverride="$2"; shift; shift ;;

        --out_dir)
            export out_dir="$2"; shift; shift ;;

        *)
            echo "Input ${1} not recognized"
            shift ;;

    esac
done

# Run pipeline
echo Converting eprime.txt to csv
eprime_to_csv.py "${eprime_txt}" -o "${out_dir}"/eprime.csv

echo Running matlab processing
xvfb-run -n $(($$ + 99)) -s '-screen 0 1600x1200x24 -ac +extension GLX' \
    run_matlab_entrypoint.sh "${MATLAB_RUNTIME}" \
    eprime_csv "${out_dir}"/eprime.csv \
    ${fmri_dcm_str} \
    timeoverride "${timeoverride}" \
    renumoverride "${renumoverride}" \
    out_dir "${out_dir}"
