#!/usr/bin/env python
from __future__ import absolute_import, division, print_function

# import vim
import subprocess
import json
import datetime

from textwrap import wrap
from terminaltables import SingleTable
from colorama import Fore
from colorama import Style

'''
Kanban for taskwarrior
'''

MAX_COMPLETED = 10  # max. no. of completed tasks to display
COLORS = {'status': 'green',
          'meta': 'yellow',
          'tags': 'yellow',
          'priority': {'H': 'red',
                       'M': 'magenta',
                       'L': 'cyan'},
          }
TAGS_ACRONYM = False


def decorate_text(text, color):
    # get text with terminal colors
    return (Fore.__getattribute__(color.upper()) + text
            + Style.RESET_ALL)


def get_tasks(tags):

    # run taskwarrior export
    command = ['task', 'rc.json.depends.array=no', 'export'] + tags
    data = subprocess.check_output(command, stderr=subprocess.DEVNULL)
    data = data.decode('utf-8')
    data = data.replace('\n', '')

    # load taskwarrior export as json data
    tasks = json.loads(data)

    return tasks


def check_due_date(tasks):

    for task in tasks:
        if 'due' in task:
            # calculate due date in days
            due_date = datetime.datetime.strptime(task['due'], '%Y%m%dT%H%M%SZ')
            due_in_days = (due_date - datetime.datetime.utcnow()).days

            if due_in_days > 7:  # if due after a week, remove due date
                task.pop('due', None)
            else:
                task['due'] = due_in_days


def make_table(tasks_dic):
    # table = [['Status', 'Meta', 'Item']]
    table_data = []
    for category in ['doing', 'todo', 'done']:
        length = len(tasks_dic[category])
        # colored_status = decorate_text(category, STATUS_COLOR)
        if length == 0:
            # table.append([colored_status, '', ''])
            table_data.append([category, '', {}])
        else:
            for k in range(length):
                item = {}
                entry = tasks_dic[category][k]
                status = category if k == 0 else ''
                project = entry.get('project', '')
                if project:
                    meta = ''.join([a[0] for a in project.split()]).upper()
                    # meta = decorate_text(meta, META_COLOR)
                else:
                    meta = ''
                item['description'] = entry.get('description', '')
                item['priority'] = entry.get('priority', '')
                item['tags'] = ' '.join(entry.get('tags', []))
                table_data.append([status, meta, item])

        # table.append(['', '', ''])
        # row delimiters not supported yet
        # https://github.com/Robpol86/terminaltables/issues/56
    return table_data


# get pending tasks
pending_tasks = get_tasks(['status:pending'])

# get tasks to do
todo_tasks = [task for task in pending_tasks if 'start' not in task]
# sort tasks by urgency (descending order)
todo_tasks = sorted(todo_tasks, key=lambda task: task['urgency'], reverse=True)
# check due dates
check_due_date(todo_tasks)

# get started tasks
started_tasks = [task for task in pending_tasks if 'start' in task]
# sort tasks by urgency (descending order)
started_tasks = sorted(started_tasks, key=lambda task: task['urgency'], reverse=True)
# check due dates
check_due_date(started_tasks)

# get completed tasks
completed_tasks = get_tasks(['status:completed'])

# master dictionary of all tasks
tasks_dic = {}
tasks_dic['todo'] = todo_tasks
tasks_dic['doing'] = started_tasks
tasks_dic['done'] = completed_tasks[:MAX_COMPLETED]

# make a table that can be passed to print_table to be printed
table_data = make_table(tasks_dic)

prepend_list = ['priority']
append_list = ['tags']
tmp_table = [[a[0], a[1],
              [' '.join([x for x in [a[2].get(y) for y in prepend_list] if x]),
               ' '.join([x for x in [a[2].get(y) for y in ['description']] if x]),
               ' '.join([x for x in [a[2].get(y) for y in append_list] if x])]] for a in table_data]
# tmp_table = [[a[0], a[1]] for a in table_data]


t = SingleTable([[a[0], a[1], ' '.join([x for x in a[2] if x])] for a in tmp_table])
t.inner_heading_row_border = False
# print to newly created buffer
# t = SingleTable(table)
max_width = t.column_max_width(2)
for i in range(len(t.table_data)):
    row = t.table_data[i]
    wrapped_string = '\n'.join(wrap(row[2], max_width))
    if row[0]:
        row[0] = decorate_text(row[0], COLORS['status'])
    if row[1]:
        row[1] = decorate_text(row[1], COLORS['meta'])
    row[2] = wrapped_string
    prepend_length = len(tmp_table[i][2][0]) + 1 if tmp_table[i][2][0] else 0
    append_length = len(tmp_table[i][2][2]) + 1 if tmp_table[i][2][2] else 0
    if not (prepend_length or append_length):
        row[2] = wrapped_string
    else:
        row[2] = wrapped_string[prepend_length:-append_length]
        for prepend in prepend_list:
            if table_data[i][2][prepend]:
                if prepend == 'priority':
                    row[2] = decorate_text(table_data[i][2][prepend], COLORS[prepend][table_data[i][2][prepend]]) + ' ' + row[2]
                else:
                    row[2] = decorate_text(table_data[i][2][prepend], COLORS[prepend]) + ' ' + row[2]
        for append in append_list:
            if table_data[i][2][append]:
                row[2] = row[2] + ' ' + decorate_text(table_data[i][2][append], COLORS[append])


print(t.table)
