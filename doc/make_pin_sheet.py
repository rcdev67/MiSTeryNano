#!/usr/bin/env python3
"""Printable pin label sheet for the Tang Nano 20K, both headers in board order.

Writes tang_nano_20k_pins.svg (English) and tang_nano_20k_pins_de.svg (German)
next to this script. The narrow strips at the bottom are true to scale
(2.54 mm pitch): print at 100 %, cut them out and lay them beside the headers.
The highlighted pins are the ones this fork uses on the M0S connector side.
"""
import os

LEFT = ['73', '74', '75', '85', '77', '15', '16', '27', '28', '25',
        '26', '29', '30', '31', '17', '20', '19', '18', '3V3', 'GND']
RIGHT = ['5V', 'GND', '76', '80', '42', '41', '56', '54', '51', '48',
         '55', '49', '86', '79', 'GND', '3V3', '72', '71', '53', '52']

TEXT = {
    'en': {
        'title': 'Tang Nano 20K - pin headers in board order',
        'sub': 'Board seen from above, USB-C at the top, HDMI at the bottom. Printed at 100 % the narrow strips match the 2.54 mm pitch of the headers.',
        'strips': 'Strips to cut out, 2.54 mm pitch (print at 100 %, not "fit to page")',
        'left': 'left header, top = USB-C', 'right': 'right header, top = USB-C',
        'legend': [('#d62828', '5 V'), ('#f08c00', '3.3 V'), ('#111', 'ground'),
                   ('#2b8a3e', 'modem and joystick'), ('#1c5fb8', 'console'), ('#e9c46a', 'leave free')],
        'note': {'41': 'modem sends  (S3 GPIO16, C3 pin 7)', '51': 'modem receives  (S3 GPIO15, C3 pin 6)',
                 '54': 'joystick bytes  (S3 GPIO17)', '48': 'companion console, output',
                 '55': 'companion console, input', '56': 'LEAVE FREE', '42': 'free',
                 '5V': '5 V  -  NEVER to GND!', 'GND': 'ground', '3V3': '3.3 V'},
    },
    'de': {
        'title': 'Tang Nano 20K - Pinleisten in echter Reihenfolge',
        'sub': 'Board von oben, USB-C oben, HDMI unten. Bei 100 % gedruckt passen die schmalen Streifen im Raster 2,54 mm neben die Stiftleisten.',
        'strips': 'Streifen zum Ausschneiden, Raster 2,54 mm (Druck auf 100 %, nicht "an Seite anpassen")',
        'left': 'linke Leiste, oben = USB-C', 'right': 'rechte Leiste, oben = USB-C',
        'legend': [('#d62828', '5 V'), ('#f08c00', '3,3 V'), ('#111', 'Masse'),
                   ('#2b8a3e', 'Modem und Joystick'), ('#1c5fb8', 'Konsole'), ('#e9c46a', 'frei lassen')],
        'note': {'41': 'Modem sendet  (S3 GPIO16, C3 Pin 7)', '51': 'Modem empfängt  (S3 GPIO15, C3 Pin 6)',
                 '54': 'Joystick-Bytes  (S3 GPIO17)', '48': 'Companion-Konsole, Ausgang',
                 '55': 'Companion-Konsole, Eingang', '56': 'FREI LASSEN', '42': 'frei',
                 '5V': '5 V  -  NIE an GND!', 'GND': 'Masse', '3V3': '3,3 V'},
    },
}


def colour(pin):
    if pin == '5V':
        return '#d62828', '#fff'
    if pin == '3V3':
        return '#f08c00', '#fff'
    if pin == 'GND':
        return '#111', '#fff'
    if pin in ('41', '51', '54'):
        return '#2b8a3e', '#fff'
    if pin in ('48', '55'):
        return '#1c5fb8', '#fff'
    if pin == '56':
        return '#e9c46a', '#000'
    return '#e9ecef', '#000'


def sheet(t):
    pitch = 2.54
    o = ['<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 210 297" font-family="Arial, Helvetica, sans-serif">',
         '<rect width="210" height="297" fill="#fff"/>',
         '<text x="105" y="14" text-anchor="middle" font-size="6" font-weight="bold">%s</text>' % t['title'],
         '<text x="105" y="21" text-anchor="middle" font-size="3" fill="#444">%s</text>' % t['sub']]
    bx, by, bw, rowh = 75, 32, 60, 9
    o.append('<rect x="%g" y="%g" width="%g" height="%g" rx="3" fill="#2f6b3a" stroke="#1d4424"/>' % (bx, by, bw, rowh * 20 + 8))
    o.append('<rect x="%g" y="%g" width="18" height="7" rx="1.5" fill="#c0c8cf" stroke="#555" stroke-width="0.3"/><text x="%g" y="%g" text-anchor="middle" font-size="3">USB-C</text>' % (bx + bw / 2 - 9, by - 3, bx + bw / 2, by + 2))
    o.append('<rect x="%g" y="%g" width="24" height="8" rx="1.5" fill="#c0c8cf" stroke="#555" stroke-width="0.3"/><text x="%g" y="%g" text-anchor="middle" font-size="3">HDMI</text>' % (bx + bw / 2 - 12, by + rowh * 20 + 3, bx + bw / 2, by + rowh * 20 + 8.5))
    cx, cy = bx + bw / 2, by + rowh * 10
    o.append('<text x="%g" y="%g" text-anchor="middle" font-size="4.5" fill="#fff" font-weight="bold" transform="rotate(-90 %g %g)">TANG NANO 20K</text>' % (cx, cy, cx, cy))
    for i, (l, r) in enumerate(zip(LEFT, RIGHT)):
        y = by + 4 + i * rowh
        for side, p in (('L', l), ('R', r)):
            bg, fg = colour(p)
            x = bx + 2 if side == 'L' else bx + bw - 16
            o.append('<rect x="%g" y="%g" width="14" height="%g" rx="1" fill="%s" stroke="#333" stroke-width="0.2"/><text x="%g" y="%g" text-anchor="middle" font-size="4" font-weight="bold" fill="%s">%s</text>' % (x, y, rowh - 1.5, bg, x + 7, y + 5.4, fg, p))
            if side == 'L' and p in ('GND', '3V3'):
                o.append('<text x="%g" y="%g" text-anchor="end" font-size="3.2" fill="#222">%s</text>' % (bx - 2, y + 5.2, t['note'][p]))
            if side == 'R' and p in t['note']:
                weight = 'bold' if p in ('5V', '56') else 'normal'
                col = '#d62828' if p == '5V' else '#222'
                o.append('<text x="%g" y="%g" font-size="3.2" font-weight="%s" fill="%s">%s</text>' % (bx + bw + 2, y + 5.2, weight, col, t['note'][p]))
    ly = by + rowh * 20 + 22
    x = 20
    for c, name in t['legend']:
        o.append('<rect x="%g" y="%g" width="5" height="5" fill="%s" stroke="#333" stroke-width="0.2"/><text x="%g" y="%g" font-size="3.4">%s</text>' % (x, ly, c, x + 7, ly + 4, name))
        x += 12 + len(name) * 2.0
    sy = ly + 14
    o.append('<text x="20" y="%g" font-size="3.6" font-weight="bold">%s</text>' % (sy, t['strips']))
    for name, pins, x0, notes in ((t['left'], LEFT, 40, False), (t['right'], RIGHT, 110, True)):
        o.append('<text x="%g" y="%g" font-size="3">%s</text>' % (x0, sy + 6, name))
        for i, p in enumerate(pins):
            y = sy + 8 + i * pitch
            bg, fg = colour(p)
            o.append('<rect x="%g" y="%g" width="12" height="%g" fill="%s" stroke="#333" stroke-width="0.15"/><text x="%g" y="%g" text-anchor="middle" font-size="1.9" font-weight="bold" fill="%s">%s</text>' % (x0, y, pitch, bg, x0 + 6, y + 1.95, fg, p))
            if notes and p in t['note']:
                o.append('<text x="%g" y="%g" font-size="1.8" fill="#222">%s</text>' % (x0 + 13.5, y + 1.9, t['note'][p]))
    o.append('</svg>')
    return '\n'.join(o)


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    for lang, name in (('en', 'tang_nano_20k_pins.svg'), ('de', 'tang_nano_20k_pins_de.svg')):
        with open(os.path.join(here, name), 'w', encoding='utf-8', newline='\n') as f:
            f.write(sheet(TEXT[lang]))
        print('wrote', name)
