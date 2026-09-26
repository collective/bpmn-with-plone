# BPMN with Plone

This project documents how to use [BPMN 2.0](https://www.omg.org/spec/BPMN/) business process models with [Plone](https://plone.org/).

BPMN stands for **Business Process Model and Notation**, an OMG standard.
BPMN provides **a visual language** that everyone from domain experts to business analysts and developers can understand.
BPMN 2.0 also defines an **executable XML format** with strict operational semantics.
Because process engines execute BPMN models directly, BPMN can eliminate the translation gap between a process specification and production code. BPMN becomes the **production code**.

This documentation accompanies a playground, which you can open in [GitHub Codespaces](https://codespaces.new/collective/bpmn-with-plone).

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/collective/bpmn-with-plone)

## States and Activities

**Plone workflows describe a content object's state** and the transitions available from that state.
**BPMN describes the work performed over time** by mode the activities and sequence of a business process.
Plone focuses on an individual document; BPMN models a process that can coordinate work across people and systems.
**They address different concerns and can complement each other.**

`````{grid} 1 1 2 2

````{grid-item}
### Plone Workflow

```{figure} images/simple-publication-workflow.png
:alt: The simple publication workflow with Private, Pending Review, and Published states
:width: 100%

State diagram of Plone’s simple publication workflow, showing its three states and their transitions.
```
````

````{grid-item}
### BPMN

```{bpmn} diagrams/publishing.bpmn
:mode: svg
:alt: BPMN publication process with author and reviewer lanes, draft creation, review, and message flows to Plone CMS
:width: 100%
:caption: BPMN model of the publication process, with author and reviewer lanes and message flows to Plone CMS.
```
````
`````

## Collaboration between BPMN and Plone

For users, Plone is a tool to help them to complete their work. Activity-based workflow like the ones defined with BPMN focus on users and their work. Users may *Create drafts and submit them* for publication, and *Review* them. Eventually the process completes, but Plone continues to manage the state of the resulting artifact, to be there for future editorial processes when required.

```{bpmn} diagrams/publishing.bpmn
:mode: simulator
:alt: BPMN publication process with author and reviewer lanes, draft creation, review, and message flows to Plone CMS
:width: 100%
:caption: Try the token simulator: start a simulation, click the start event, then click enabled activities and sequence flows to advance the token through the process. Reset the simulation to try again.
```

## Contents


```{toctree}
:maxdepth: 2

setup
```
