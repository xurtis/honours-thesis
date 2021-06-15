Time demand analysis
====================

.. include:: ../../utils.rst

Time demand analysis is a procedure by which we can determine the
schedulability of a real-time system. We say a set of real-time tasks is
schedulable if all jobs of that task will complete execution before
their deadline. If the execution time of a job and the time spent
performing any other execution in a system is less then the duration
between the release of that job and its deadline, then the job will
complete execution before the deadline if no execution in the system is
otherwise delayed.

As it is often hard to know the precise execution time for every job in
the system and the amount of system execution that interferes with the
execution of every job, we instead only check the schedulability of a
task based on the upper bounds of each kind of execution. We determine
some *overestimate* for the worst case execution time (WCET) for all the
jobs of a real-time task and assume that each job may demand that amount
of time.  We then need to determine an overestimate of the worst case
for the execution that may occur outside that task for any job in that
task and assume that execution may always be demanded within a period of
the relative deadline of each job of that task.

If we attribute all execution in a system to the tasks in the task set,
then all execution outside of a given task is a result of some other
task. For a priority-based scheduling algorithm, the execution of a job
in a task may be delayed by the execution of a job of some other task
in two situations: if the delayed task has a lower *priority* to the
task that is executing or if the delayed task requires a resource that
has been acquired by a task with any priority. The latter case is known
as *priority inversion* as a job with a particular priority can execute
in preference to a task with a higher assigned priority.

The worst case for these sources of execution that are *external* to a
task being checked is the sum of the worst cases for higher-priority
execution and priority inversion. :citet:`Liu:rts` shows us that the
worst case for higher-priority execution occurs when a job from each
higher-priority task is released in-phase with a task being checked such
that the full execution time of each higher priority task occurs before
any execution of the task being checked. If multiple jobs of a
higher-priority task could occur in the period between the release and
deadline of a job for the task being checked, then the worst case also
assumes the maximum number of jobs for that higher-priority task are
released. For a fixed-priority scheduling algorithm, such as
the *deadline-monotonic* (DM) scheduling algorithm, the set of
higher-priority jobs is always the same and, if a minimum inter-arrival
time is applied, so is the maximum number of jobs that can be released
in any period. This makes the task of determining the worst case
higher-priority execution particularly straightforward.

The system must guarantee the upper bound on the execution that any
lower priority task may make before releasing a resource that may be
required by the task being checked or by any task at a higher priority.
If the resource sharing policy allows multiple such resources to be held
concurrently by different lower-priority tasks, this worst case must be
considered for the maximum number of concurrently held resources. The
*priority ceiling protocol* (PCP) is ensures that, at the time a task is
released, only one lower-priority task may hold a resource in this
fashion and so this execution cost only needs to be considered as a
single cost.

We can thus determine the schedulability for a task set
:math:`\mathbf{T}` that is scheduled according to the
deadline-monotonic algorithm and that uses priority-ceiling protocol to
schedule access to shared resources as follows. For each task
:math:`T_n \in \mathbf{T}` we assume a worst case execution :math:`W_n`,
priority :math:`p = P_n`, relative deadline :math:`D_p`, and minimum
inter-arrival time :math:`A_n`. We also assume that the scheduler or
system enforces a worst case priority inversion time at that priority of
:math:`I_p`. We then determine the set of higher-priority tasks to be
:math:`\mathbf{H}_n = \lbrace x : P_x \ge P_n \rbrace`. We can then
consider the task schedulable if the following is true:

.. math::

    D_p \ge
      I_p +
      W_n \left \lceil \frac{D_p}{A_n} \right \rceil +
      \sum_{h \, \in \, \mathbf{H}_n} W_h
        \left \lceil \frac{D_p}{A_h} \right \rceil

In a deadline-monotonic system it is possible that many tasks, with
equal relative deadlines, are assigned equal priority. In this case, it
is equivalent to check the entire priority level by collecting the tasks
for that priority together as :math:`\mathbf{G}_p = \lbrace x : P_x = p
\rbrace` and by redefining the set of higher-priority tasks to only
include tasks of a strictly higher priority as :math:`\mathbf{H}_n =
\lbrace x : P_x > P_n \rbrace`. We then consider the entire priority
level to be schedulable if the following is true as it is equivalent to
the conjuction of the test above for an entire priority level.

.. math::

    D_p \ge
        I_p +
        \sum_{n \, \in \, \mathbf{G}_p} W_n
            \left \lceil \frac{D_p}{A_n} \right \rceil +
        \sum_{h \, \in \, \mathbf{H}_n} W_h
            \left \lceil \frac{D_p}{A_h} \right \rceil

We can also observe that if we substitute a task with a given minimum
inter-arrival time and worst case execution time with an arbitrary
number of tasks with the same priority and minimum inter-arrival time
and that have a combined worst case execution time equal to that of the
original task, then the interference on lower-priority tasks is
unchanged. This allows us to introduce *sporadic server* (SS)
:cite:`Sprunt_SL_89` into our task set without modification to the above
test, as they operate by simulating an arbitrary number of such
divisions of an aperiodic task.

If we use the kernel scheduler to enforce the worst case execution time
and minimum inter-arrival time as well as the bound on priority
inversion, this *admission test* can tell us whether any set of tasks
will be schedulable with the DM algorithm and PCP resource sharing
protocol. If we can guarantee these bounds in the kernel, then the
ability for any task to meet its deadline depends only on its own
correctness, the correctness of any shared resource implementation, that
the WCET enforced by the kernel is no less than its actual WCET of the
task, and that the kernel enforced priority inversion bound at any
priority level is no less than the WCET of any shared resource access
that occurs at that priority. This ensures that the correctness of any
task does not depend on the correctness of any other task when no
dependency relationship exists.

Whilst the constraints regarding scheduling algorithm and resource
sharing protocol here do simplify the means by which we perform the
check, the general approach can be applied to a wider range of
scheduling configurations without significant change to the properties
that must be enforced by the kernel or the trust relationship between
tasks. This is what will ensure that we can provide the robust
scheduling guarantees necessary for mixed-criticality systems.

.. add summary paragraph

.. What does time demand analysis seek to solve?

   Guarantee that all jobs will complete before their deadline

.. What are the principles upon which it works?

.. How do the prinicples map to the properties of a particular
   scheduling algorithm?

.. What in the schedule can cause a change in the analysis?
   Any execution that may occur in the deadline window

.. takeaway paragraph - time demand analysis
