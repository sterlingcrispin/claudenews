#!/usr/bin/env python3
"""Parse RSS/Atom XML from stdin, output TSV: source\ttitle\tdescription\tlink"""

import sys
import xml.etree.ElementTree as ET
import re
import html


def clean(text):
    if not text:
        return ""
    text = re.sub(r"<!\[CDATA\[|\]\]>", "", text)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    return " ".join(text.split()).strip()


def first_sentence(text):
    if not text:
        return ""
    m = re.match(r"(.*?[.!?])(?:\s|$)", text)
    if m:
        s = m.group(1)
        return s[:197] + "..." if len(s) > 200 else s
    return text[:197] + "..." if len(text) > 200 else text


def main():
    if len(sys.argv) < 2:
        sys.exit(1)
    name = sys.argv[1]

    xml_data = sys.stdin.read()
    try:
        root = ET.fromstring(xml_data)
    except ET.ParseError:
        sys.exit(1)

    ns = {"atom": "http://www.w3.org/2005/Atom"}
    items = root.findall(".//item")
    if not items:
        items = root.findall(".//atom:entry", ns)

    for item in items:
        title_el = item.find("title")
        if title_el is None:
            title_el = item.find("atom:title", ns)
        desc_el = item.find("description")
        if desc_el is None:
            desc_el = item.find("atom:summary", ns)
        link_el = item.find("link")
        if link_el is None:
            link_el = item.find("atom:link", ns)

        title = clean(title_el.text if title_el is not None and title_el.text else "")
        desc = first_sentence(
            clean(desc_el.text if desc_el is not None and desc_el.text else "")
        )
        link = ""
        if link_el is not None:
            link = link_el.text or link_el.get("href", "")
            link = re.sub(r"[\t\n\r]", "", link.strip())

        if title:
            print(f"{name}\t{title}\t{desc}\t{link}")


if __name__ == "__main__":
    main()
