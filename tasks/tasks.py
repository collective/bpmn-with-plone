"""External task handlers, served with `operaton-tasks serve tasks/tasks.py`.

A handler is called for each external task on its topic. Point a BPMN service
task at it by setting its implementation to "External" with the same topic.
"""

from operaton.tasks import task
from operaton.tasks.runtime import ExternalTaskComplete
from operaton.tasks.types import CompleteExternalTaskDto
from operaton.tasks.types import LockedExternalTaskDto
from operaton.tasks.types import VariableValueDto


@task(topic="hello")
async def hello(task: LockedExternalTaskDto) -> ExternalTaskComplete:
    """Complete the task, setting the process variable `greeting`."""
    return ExternalTaskComplete(
        task=task,
        response=CompleteExternalTaskDto(
            workerId=task.workerId,
            variables={"greeting": VariableValueDto(value="Hello!", type="string")},
        ),
    )
