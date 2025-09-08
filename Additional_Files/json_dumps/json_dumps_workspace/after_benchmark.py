import json
import sys

import pyperf

#* Part 1: Data Structure Setup

EMPTY = ({}, 2000)

# Python dictionary (like std::map in C++)
SIMPLE_DATA = {'key1': 0, 'key2': True, 'key3': 'value', 'key4': 'foo',
               'key5': 'string'}

# Python tuple (like std::pair in C++)
SIMPLE = (SIMPLE_DATA, 1000)    # (data_object, iteration_count)

NESTED_DATA = {'key1': 0, 'key2': SIMPLE[0], 'key3': 'value', 'key4': SIMPLE[0],
               'key5': SIMPLE[0], 'key': '\u0105\u0107\u017c'}
NESTED = (NESTED_DATA, 1000)
HUGE = ([NESTED[0]] * 1000, 1)

#* Test Cases
'Purpose:'
'test1: Tests minimal JSON encoding overhead'
'test2: Tests common primitive types'
'   Tests CPU-bound performance (algorithms, string processing)'
'test3: Tests nested objects + Unicode handling. tests scalability.'
'   (memory-bound performance (allocation, bandwidth, cache behavior)) '
'   Key Challenge: SIMPLE[0] creates object references (not copies!)'

'Performance Focus:'
'test1: Function call overhead, basic string allocation'
'test2: Type dispatch, string escaping, primitive serialization'
'test3: Recursion, circular reference detection, Unicode escaping'
CASES = ['EMPTY', 'SIMPLE', 'NESTED', 'HUGE']

#* Part 2: Core Benchmark Function

def bench_json_dumps(data):
#* Edit 1: Lookup once: avoids LOAD_GLOBAL + LOAD_ATTR each iteration
    dumps = json.dumps  
    for obj, count_it in data:  # Unpack: obj=data_to_serialize, count_it=iterator
#* Edit 2: Batch processing to reduce per-call overhead
        count = len(count_it)  # range(count) has __len__
        
        # Pre-create batch to reduce argument setup overhead
        batch = [obj, obj, obj, obj]
        
        #* Process 4 calls per loop iteration using batch iteration
        i = 0
        while i < count - 3:
            for item in batch:
                dumps(item)
            i += 4      
        
        # Handle remaining calls
        while i < count:
            dumps(obj)
            i += 1
#     for obj, count_it in data: # Unpack: obj=data_to_serialize, count_it=iterator
#         for _ in count_it:  
#             dumps(obj)   #* improve 1: Direct function call, no attribute lookup

#* Helper for command-line options
def add_cmdline_args(cmd, args):
    if args.cases:                          # If user specified --cases argument
        cmd.extend(("--cases", args.cases)) # Add it to command list


def main():
    runner = pyperf.Runner(add_cmdline_args=add_cmdline_args)
    runner.argparser.add_argument("--cases",
                                  help="Comma separated list of cases. Available cases: %s. By default, run all cases."
                                       % ', '.join(CASES))
    runner.metadata['description'] = "Benchmark json.dumps()"

    args = runner.parse_args()
    if args.cases:
        cases = []
        for case in args.cases.split(','):
            case = case.strip()
            if case:
                cases.append(case)
        if not cases:
            print("ERROR: empty list of cases")
            sys.exit(1)
    else:
        cases = CASES

#* Part 3: Test Case Construction

    data = []           # Empty list to store test cases
    for case in cases:
        obj, count = globals()[case]    #Returns a dictionary of all global variables in current module
        data.append((obj, range(count)))

    runner.bench_func('json_dumps', bench_json_dumps, data)
    '''
    What bench_func does:
        1. Calls your function (bench_json_dumps) many times
        2. Measures timing for each run
        3. Does statistical analysis (mean, standard deviation, etc.)
        4. Handles warm-up to avoid cold cache effects
        5. Reports results in a standardized forma
    '''


if __name__ == '__main__':
    main()

'''
#* Part 4: Performance Bottlenecks

1.SIMPLE Case: {'key1': 0, 'key2': True, ...}
Bottlenecks: Dictionary iteration, type checking (int/bool/string), string escaping

2. NESTED Case: Contains Unicode '\u0105\u0107\u017c'
Bottlenecks: Recursive encoding, Unicode escape sequences

3. HUGE Case: [NESTED_DATA] * 1000 (1000-item array)
Bottlenecks: Memory allocation, cache misses, repeated work

Each case tests different performance aspects of json.dumps()!
'''
