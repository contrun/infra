#!/usr/bin/env python3

import i3


def focus_next():
    num = i3.filter(i3.get_workspaces(), focused=True)[0]['num']
    ws_nodes = i3.filter(num=num)[0]['nodes']
    curr = i3.filter(ws_nodes, focused=True)[0]

    ids = [win['id'] for win in i3.filter(ws_nodes, nodes=[])]

    next_idx = (ids.index(curr['id']) + 1) % len(ids)
    next_id = ids[next_idx]

    print(next_id)
    i3.focus(con_id=next_id)


def main():
    focus_next()


if __name__ == '__main__':
    main()
