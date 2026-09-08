# Nearby links guide

GUIDE START. This document is the M1-10 source. Every link below is an ordinary relative path resolved from this file's folder (`docs/`).

## Markdown targets with sections

- [Intro second section](./intro.md#second-section)
- [Parent readme](../README.md#parent-section)
- [Deep target](sub/deep.md#deep-target)
- [Plain sibling](intro.md)

## Spaces and encoded filenames

- [Spaces bracketed](<my notes.md>)
- [Spaces encoded](my%20notes.md)
- [Encoded Unicode](caf%C3%A9.md)
- [Literal Unicode](café.md)
- [Percent edge](100%.md)

## Leading slash policy

- [Root target](/root-target.md)

## Other local types

- [Plain text notes](notes.txt)
- [Linked image](img/diagram.png)
- [![Diagram link](img/diagram.png)](img/diagram.png)

## Errors

- [Missing file](missing.md)
- [Missing nested](sub/absent/nowhere.md)
- [Missing section](intro.md#nowhere)
- [Private file](private.md)

## Same document and internal

- [Same document section](guide.md#guide-end)
- [Internal only](#guide-end)
- [Web reference](https://example.com/)

## Images

![Diagram](img/diagram.png)

![Missing image](img/absent.png)

## Guide end

GUIDE END. Reaching this heading through the same-document link proves refocus plus section navigation.
