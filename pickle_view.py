#!/usr/bin/env python

# Simple script to view contents of a cookie file stored in a pickle format

import sys
import fickling

if __name__ == '__main__':
    argv = sys.argv
    if len(argv) <= 1:
        print("Specify a pickle file as a parameter, e.g. cookies/user.pkl")
    else:
        print(fickling.load(open(argv[1], 'rb')))
