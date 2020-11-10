===============================================================
 Enforcing real-time assumptions for mixed-criticality systems
===============================================================

.. include:: ../utils.rst

:Author: Curtis Millar
:Date: |today|
:Abstract:
    TODO: Write the abstract.

Introduction
============

.. note:: I think this is written too much in the passive voice...

The schedulability of real-time systems is a long studied and well
understood field of research. Many algorithms have been identified for
producing schedules of real-time task sets with complimentary algorithms
for determining whether or not a particular set of tasks is
*admissable*, that is, whether or not the set of tasks will always be
scheduled such that all tasks may meet their deadlines. These
*admissions tests* operate under a set of assumptions, particularly with
regard to the worst case execution of each task in the set as well as
the bounds for priority inversion.

Mixed-criticality systems are those where some tasks must not be allowed
to depend on the behaviour of other tasks. In these systems, we cannot
simply assume that the behaviour assumed for admissions tests will be
exhibited by untrusted tasks at run-time; we must instead guarantee that
the untrusted tasks cannot violate the assumptions made for the purposes
of the admissions test. Two of the most common approaches for for
guaranteeing behaviour in such systems are formal verification, which
can prove that certain properties are true of software, and run-time
enforcement, wherein a trusted monitor can detect and prevent certain
behaviours that would violate the properties to be enforced.

.. note:: Need to perhaps be more specific that this regards trust in
   scheduling behaviour?

As the use of formal verification can be complex, expensive, and
can restrictive, we instead choose to devise a set of run-time mechanism
within a small, trustworthy runtime monitor that enforce the properties
assumed by real-time admissions tests.

.. note:: Also need to point out at some point that as we are enforcing
   bandwidth, we need to attribute time to the correct tast.

.. note:: Is this introduction too abstract?

In this paper we present a set of mechanisms that enforce execution
times, bound priority inversion, bound preemptions, and ensure correct
attribution of execution to tasks. We show that by enforcing these
properties we can guarantee the schedulability of a mixed criticality
system using the sporadic server algorithm :citet:`Sprunt_SL_89a` and
the highest locker's protocol (HCP) (also known as the immediate
priority ceiling protocol) to account for priority inversion in shared
servers.  We then show how the seL4 microkernel can be modified to
enforce these real-time properties.

.. Wikipedia would have me believe that we are using the 'immediate
   priority ceiling protocol' (as distinct from the 'orignial priority
   ceiling protocol') but the references paper only describes the
   'priority ceiling protocol' and I can't find a good source for the
   'immediate' or 'original' named variations. :cite:`Liu:rts` only has
   'priority ceiling protocol' which appears to be analagous to OCPC.

The remainder of this paper will be structured as follows;
:ref:`background` will introduce real-time concepts,
mixed-criticality systems, and the seL4 verified microkernel,
:ref:`real-time-assumptions` will outline the real-time model used and
the assumptions made for the purposes of admissions testing,
:ref:`guaranteed-enforcement` will describe the approaches we can use to
guarantee the real-time assumptions, :ref:`implementation-in-sel4` will
show how we implement these mechanisms in the seL4 microkernel,
:ref:`evaluation` will evaluate the efficacy and overheads of the
implementation, :ref:`conclusions` will summarise the findings of the
paper, :ref:`future-work` will outline future work that will extend on
the findings, and :ref:`related-work` will discuss related work in the
existing literature.

.. note:: What are our contributions?

..  1. Problem statement
    2. Contributions

     * We have a set of techniques that, under the assumption that the tasks
       in a system behave a certain way, we can show that all tasks the
       system will always be able to meet deadlines for a particular
       scheduling algorithm.
     * SpSL sporadic server is a useful algorithm as it can model classical
       periodic and aperiodic tasks as well as non real-time tasks at any
       set of priority levels.
     * In a mixed criticality system, high-crticiality tasks depend on all
       other tasks actually behaving in the manner assumed for the asmission
       test.
     * Specifically, we need to enforce that no task executes for greater
       than the WCET used for the admission test and that no task can be
       delayed due to priority inversion for more time than described in
       admission test.

Background
==========

The sporadic server algorithm
-----------------------------

.. note:: less passive, more 'we'?

:citet:`Sprunt_SL_89a` produced a model of *sporadic servers* which
behave as an infinite set of aperiodic tasks of equal period and
infinitely small execution time that sum to the budget of the task
itself. Each of these infinitely small sub-tasks also preserve a strict
ordering. Each sub-task is never allowed to execute more frequently than
once per period, so if a sub-task is released in response to an
aperiodic event later than the start of its period, the subsequent
release will be no sooner than one period in the future. This
effectively shifts the phase of each sub-task be the delay between the
start of the period and the arrival of an aperiodic event.

In a case where the complete task only responds to a single periodic
event at the start of each period, the task acts in an identical manner
to a classical periodic task. In fact, the continuous execution time of
the task is bounded above by the equivalent periodic task such that we
can use rate-monotonic priority assignment and admissions testing.

We can also use this model for tasks that respond to aperiodic events,
including those that handle multiple aperiodic events within their
period, without needing to adjust the algorithms for priority assignment
and admissions testing.

Mixed-criticality systems
-------------------------

:tocite:`something authoritative on mixed-criticality systems?`.

The *criticality* of a component in a mixed-criticality system describes
the degree to which that system can tolerate its failure. For example,
if a  *safety-critical* component fails, human lives may be at risk, and
if a *mission-critical* component fails, the system may not be able to
:reword:`complete its designed function`. The system may be able to
recover if a *low-criticality* component fails. Many systems for
formally categorising the criticality of components already exist
:tocite:`automotive & aerospace regulations`.

The criticalities of a system are strictly ordered such that a component
does not depend on another component of a lower criticality. If a
component fails, it must not impact the operation of any component of a
higher criticality. We say that the higher criticality does not *trust*
components of lower criticality in that it does not trust them to
exhibit any particular behaviour such as correct execution, or execution
within some bounds. If we depend on any particular behaviour of a task
that is untrusted, we must guarantee that behaviour externally.

Shared servers and priority ceiling protocol
--------------------------------------------

:tocite:`Is there a particular paper this idea comes from?`

Multiple tasks in a real-time system can share access to a resource via
a shared server. When a task accesses the shared resource it transfers
execution to the shared server which has direct and exclusive access to
the resource. When the operation is complete execution is transferred
back to the task. The server's execution is considered part of the
execution of the task which transferred its execution.

The highest locker's protocol (HLP) assigns a priority to the shared
server that is one greater than the priority of all of its clients. This
ensures that when any client is executing within the server, no other
client can execute until the server returns execution to the client. In
a uniprocessor system, this ensures that any client that can execute can
exclusively access all of its resources without blocking.

Shared servers also introduce *priority-inversion*, wherein a task may
have its execution delayed by a task of a lower priority accessing a
resource shared with tasks of an equal or higher priority. This can
occur even between tasks that share no resources.

seL4
----

:citet:`Klein_AEHCDEEKNSTW_10` introduced the seL4, a formally verified
microkernel. It is a trustworthy foundation utilising capability-based
access control to provide primitives to construct isolated protection
domains, scheduling of threads executing within those protection
domains, and mechanisms for controlled communication between threads.

.. note:: Need to explain:

    * Threads
    * Scheduling
    * IPC
       * Endpoints
       * Notifications
       * Reply objects
    * User-level interrupt handling
       * Interrupt handlers
    * Real-time
       * Scheduling contexts

:citet:`Lyons:phd` extended seL4 with features to support
mixed-criticality real-time systems, introducing an explicit notion of a
scheduling context (SC) within the kernel that controls access to
execution time on a processor. The communication mechanisms were also
extended to allow these SCs to be passed between threads, allowing
multiple threads to execute on a single reservation of time. We can
implement real-time tasks as a scheduling context and a set of one or
more threads which will execute using the SC. We can implement shared
servers as *passive servers*, which have no scheduling context of their
own but can execute on the SC donated from a client.

.. note:: Explain the basics of changes made to the scheduler, refill
   logic, etc.

Real-time assumptions
=====================

.. What assumptions are made by the SpSL admission test?
   What do these assumptions mean in the context of MCS?

The sporadic server algorithm :citet:`Sprunt_SL_89a` produces tasks that
can behave identically to periodic tasks for the purposes of the
rate-monotonic priority assignment and schedulability analysis produced
by :citet:`Liu_Layland_73`. They show that the scheduling algorithm will
never cause a task to execute for more time that if it were scheduled
periodically, even in the presence of delayed execution. The algorithm
also enforces an upper bound on the execution of a task, preventing it
from executing for more time than it has available.

Attributing execution time
--------------------------

Whenever a task is selected to execute, we must charge the time spent
executing to that task's :clarify:`budget`. If we charge execution of
that task to the budget of any other task, then that other task may not
get sufficient time to complete. Any time that could be erroneously must
be eliminated or bounded such that it can be considered when determining
the schedulability of a task.

In an ideal model, when we switch from executing one task to another,
there is a single instant where the first task stops execution and the
second task continues at the next instruction it would have performed
when it was last executing. Additionally, only the time before this
instant is charged to the first task and only time after this instant is
changed to the second task.

In real system, we switch between tasks as a result of some external
interrupt such as a timer. This external interrupt switches to
:clarify:`scheduling code` that is part of neither task that selects the
next task to execute before returning execution to the second task.
Although we know the time at which a timer interrupt was configured to
be delivered, we do not know the time of the precise instant when the
first task stopped execution, nor the precise time of when the second
task began execution. We have additionally spent some amount of time
executing for which we must account in our schedulability analysis. If
there is any inaccuracy in attributing time to either task, this can
cumulate over many switches and can drastically increase the execution
time we observe of tasks that are frequently pre-empted.

.. How is this issue dealt with in other systems? Why are those
   solutions insufficient?

.. What is the budget of a task?

.. Introduce the kernel more explicitly

.. The execution attributed to a task must be a result of that task's
   implementation. Why? Enforcement?

.. If we charge external time to a task, that task actually requires
   more time to execute. If we can avoid having to account for this, we
   should.

.. Need to make sure that no execution from a task is attributed to
   another task.

..
    Non-preemptable kernel sections
    -------------------------------

    .. We should have some expectation at this point regarding the duties of
       the kernel. We should also assume the existence and involvement of
       the kernel. Specifically, we should assume seL4 or kernels like seL4.

    In addition to scheduling tasks, the operating system kernel manages the
    protected state of the operating system and responds to external
    interrupts. In doing so, it may enter into large non-preemptable
    sections which 

    .. Need to account for non-preemptable sections in the kernel, needs to
       be attributed to the correct task.

Bounded pre-emption
-------------------

Whenever an external interrupt occurs, we execute a global interrupt
handler in response and spend some amount of time updating kernel state.
We must attribute the time spent handling interrupts to some task that
could have been selected to execute at the time the interrupt was
handled, i.e., a task of equal or higher priority than the current task
with available execution budget. If no such task is directly associated
with the interrupt, the next most obvious choice is whichever task
happened to be executing at the time the interrupt is delivered.

In order to account for this, we must know the worst-case execution of
the interrupt handler and bound the preemptions such that they can be
considered in the execution time of the tasks that could be charged the
cost.

.. Need to bound the number of preemptions, each pre-emption can come
   with a cost.

.. Not all pre-emptions can be readily associated with a task, the
   number of these should be bounded.

Bounded priority-inversion
--------------------------

:citet:`Sha_RL_90` outline the issue of *priority-inversion* wherein a
low priority task can block execution in a higher priority task by
acquiring exclusive access to a resource shared by that higher-priority
task. They then show that the priority ceiling protocol (PCP) can
produce a schedulable system using rate-monotonic scheduling and shared
resources when the worst case of delay due to priority inversion is
known for each task in the system. The same logic can be used for
schedulability analysis of the highest locker's priority (HLP) protocol,
also known as the immediate priority ceiling protocol, which causes the
same worst case blocking cases.

In the context of a system where tasks of high-criticality must not
depend on tasks of low-criticality, we must ensure that no low
criticality task can violate the assumptions made for this worst case
delay time on any higher criticality task, as such we should bound the
time that untrusted tasks can execute at an increased priority.

.. Need to ensure that no untrusted task can invert priority for more
   than the assume bound.

Guaranteed enforcement
======================

.. How can we guarantee in the seL4 kernel that the real-time
   assumptions are sound?

Kernel time attribution
-----------------------

In order to resolve the issue regarding attribution of thread switching
time, we must be able to consistently determine the point at which one
task stops and another task starts and we must ensure the cost of
switching tasks can be :reword:`accounted for` when we perform
schedulability analysis. We can simplify the schedulability analysis by
always charging the switching cost to the pre-empting thread in the case
of pre-emption and to the already executing thread in all other cases.
In our analysis, we can simply assume that each activation will result
in two task switches being charged, one at the start of execution and
one at the end. :tocite:`Work that already outlines this approach of
charging the cost of task switching twice.`

.. I suspect there is existing literature that describes this approach
   of accounting for task switching costs in this manner.

When a higher priority task pre-empts a lower priority task, we charge
the higher priority task for the entry into the kernel and the exit from
the kernel. Although we cannot accurately determine the instance when
the pre-empted task stops or resumes execution, we can estimate the
instance in such a way that any error is charged to the pre-empting
task. Thus, whenever a task is pre-empted, it can only be granted extra
execution time from the task that pre-empted it.

Although we could assume that the time that the preempted task stopped
executing is the time at which the timer interrupt was programmed to be
delivered, this assumption would be incorrect. If the pre-empted task is
in a non-preemptable section (e.g., within a syscall in the operating
system kernel) the task will not actually finish executing until after
the end of the non-preemptable section. The difference between the
configured interrupt time and the actual time the pre-emtped task
stopped executing would then be charged to the preempting task, and this
amount could be as much as the longest possible non-preemptable section
in the preempted task.

Instead, we make a pessimistic approximation of the worst-case latency
between the time that an interrupt is delivered outside of a critical
section and the time when the current time is read by the kernel on the
interrupt path. We then assume that when we read the time in the kernel,
the interrupted task stopped executing this amount of time before the
kernel reads the timer. Similarly, we make a pessimistic approximation
for the worst case latency between the kernel reading the time at the
before resuming a pre-empted task and the time at which that task can
execute its first instruction. We assume that a task will always resume
this amount of time after the kernel has read the timer.

.. note:: Add timeline graphic describing each of the points in time.

Within seL4 we can determine upon entry into the kernel whether we will
need to read the timer at the start of kernel execution, to determine
the time when a pre-empted task stopped executing, or at the end of
kernel execution, to determine when the resumed task will continue
execution. The only cases where we would charge the cost of kernel
execution to the task that would be resumed is when that task pre-empts
and already executing task, i.e., when the entry is due to an event not
triggered by the currently executing task. The only cases where this
occurs are for handling interrupts managed at user-level or when the
timer interrupt is set to indicate the release of an equal or higher
priority task. In all other cases, the cost of kernel execution can be
charged to the task that was executing upon entry into the kernel.

Rate-limiting interrupts
------------------------

.. How do we enforce a rate limiting on interrupt handlers?
   Force ack to block on notification / passive endpoint & consume
   remaining time. Somehow combine this with an arbitrary NBSend?

.. Has this problem already been solved?

In cases where an external interrupt is delivered and the interrupt
handler is at an equal or higher priority than the currently executing
task and has available execution budget, we can pre-empt the currently
executing task and switch to the interrupt handler, having already
accounted for the cost of task switching for pre-emption. In cases where
an external interrupt occurs but interrupt handling task is available to
execute, either because it runs at a lower priority or does not have
available execution budget, the cost of switching to the kernel,
acknowledging the interrupt, managing kernel state, and returning to
user-level is all charged to the currently executing task.

Every task must be provided the necessary budget to handle all
interrupts that are delivered in this fashion and they must all be
considered in the scheduling analysis. If we can bound the worst-case
execution cost for handling an interrupt in this manner and we can bound
the number of times this can occur within a given task, we can account
for this when budgeting time for tasks and when analysing schedulablity.

When the interrupt handler is at a lower priority than the currently
executing task, we know that the interrupt will only be delivered once
as the interrupt will only be acknowledged and unmasked once that task
is later able to execute.

Without additional enforcement, it is theoretically possible for an
untrustworthy or malicious task with a higher priority to cause an
intractably large number of these pre-emptions within a single period in
a manner that is bounded by that task's total available budget. If it
can configure a pair of interrupts such that it configures both to
triggered at a high frequency but always waits for the later of the two,
we will always charge the cost of handling the earlier interrupt to a
lower-priority task.

A simple approach that can be used to effectively bound the number of
times a high-priority task can configure external interrupts is to
exhaust the available budget of the interrupt handler when it
acknowledges and unmasks an interrupt. This ensures that the last action
an interrupt handler takes is to unmask and acknowledge a single
interrupt. If we also limit the number of future sporadic replenishments
a task may have, this also ensures that the task can only program an
acknowledge and unmask once per replenishment. Further, if that task is
only ever activated by that interrupt, the task can only handle one
interrupt per period.

Given this constraint, we can assume that any task will never have to
account for more interrupts being handled than total number of times
equal or higher priority interrupt-handling tasks could be replenished
per period plus the number of lower-priority interrupt handling tasks.

.. Should this have an equation?

Bounding priority-inversion
---------------------------

While enforcing the scheduling rules of the sporadic server algorithm
:cite:`Sprunt_SL_89a` is sufficient to guarantee the scheduling of a set
of independent tasks of differing criticality, it is insufficient if any
of those tasks share resources in way that would lead to
priority-inversion :cite:`Sha_RL_90` and delay of high-criticality
tasks. If we only enforce that tasks are bound by their sporadic
replenishments, a task may still execute for its entire available
execution budget at a raised priority which may be far greater than the
assumed worst case delay for lower-priority tasks in our scheduling
analysis.

To resolve this, we must enforce a maximum execution time for any
critical section of a shared resource. If this maximum execution is
enforced by the kernel, the worst case delay a task may observe due to
priority inversion is the longest critical section of all resources at a
higher priority. If we associate each resource with an operating-system
thread with no time reservation of its own, we can use this thread to
control access to a shared resource with a priority equal to the highest
of all of the tasks that may access it. To access a resource, a task
must transfer execution and available budget to this *shared resource
server* for the duration of exclusive access to the shared resource. To
enforce the bound on priority inversion, we assign an execution bound to
the resource server, a task accessing the server is blocked until it has
sufficient time available to execute for the entirety of this bound and
no more than this amount may be transferred to the resource server.

This enforcement ensures that a client may only access a shared resource
when it can bare the cost of a worst case operation and that tasks with
a lower priority than the server will never be delayed by more than the
bounded execution time of the server.

.. Need to know OS threads at this point.

Implementation in seL4
======================

Attributing execution time
--------------------------

.. note::
    * How do we determine the worst case time from interrupt to
      timestamp read? Is this execution path the same in all cases?
    * How do we determine the worst case time from timestamp read to
      task resume? Is this the same code-path in all cases?
    * Is it sufficient to simply determine these through observation?

.. note::
    * Modify the entire scheduler so that lower-priority tasks cannot
      trigger kernel preemptions in higher priority tasks due to shared
      release queue (i.e., release queue per priority level).
    * When we set configure the kernel timer we set a flag to indicate
      whether the timeout is for preemption or budget exhaustion.
    * If we enter the kernel due to a user-level managed interrupt, or
      timer interrupt for preemption (or IPI?), we read the timestamp on
      entry and subtract the entry latency. This time is used as the
      instant the tasks switched when charging time if a task switch
      occurs.
    * If we enter the kernel for a fault or syscall, we read the time at
      the latest possible point in the kernel (if there is a change in
      SC), just before we change the current SC and resume the next
      thread to execute. We add the kernel exit latency to the timestamp
      read and charge the time to the SC that was used on entry.

Rate-limiting external interrupts
---------------------------------

.. note::
    * Acknowledging an interrupt depletes the remaining available budget
      of the current SC.
    * Add an invocation on interrupt handlers that acks, signals one
      notification, then blocks to wait on a second notification or
      endpoint?

       * We don't have precedent for performing what is effectively 2
         'send' operations in a single syscall.
       * Can't do send on an endpoint atomically with an ack (the
         protocol for syscalls isn't compatible) only notification (but
         this should be sufficient).

Bounding priority inversion
---------------------------

.. note::
    * Add a 'passive budget' property to threads

       * To perform a donating send to a thread, you must have at least
         this amount of time readily available

    * Extend reply objects to record available budget that wasn't
      donated and add *non-donated budget* to SCs.

       * When you perform a donating send to a thread, the difference
         between the available budget in the SC and the passive budget
         of the receiver is recorded in the reply object and added to
         the SC's *non-donated budget*.
       * The available budget in the SC is then reduced to the passive
         budget of the receiver.
       * When the server replies, add the amount in the reply object
         back to the available budget of the SC and subtracted from the
         *non-donated budget* of the SC.
       * When an SC is explicitly bound to a thread, any time from the
         *non-donated budget* is returned to the available budget of the
         SC. This ensures that while no passive server can abuse an SC
         to get more time than it would be permitted by deleting
         portions of the call stack, the SC preserves its configured
         budget such that the SC could be removed by a timeout monitor
         and returned to the original client without losing the time
         stored in the call stack.

Evaluation
==========

.. How was this implemented? Was the implementation effective?

.. Demonstrate that untrustworhty workload is constrained so that
   critical tasks still meet deadlines.

Conclusions
===========

.. What conclusions can we draw from this?

Future work
===========

.. What work still needs to be done?

Related work
============

.. What work relates to solving this problem?

.. http://people.cs.ksu.edu/~danielwang/Investigation/System_Security/00990608.pdf

.. @inproceedings{deNizD2001Rsir,
        abstract = {The resource-sharing problem in priority-driven realtime systems has been studied at length, with the result that some effective and practical solutions are available for both fixed-priority and dynamic-priority systems. In recent years, real-time operating systems have begun to support the resource reservation paradigm, providing a "temporal isolation" abstraction. However the problem of sharing logical resources across reserved applications has not been extensively studied. In this paper we consider both the theoretical and practical implications of such resource-sharing in reservation-based systems. Moreover we provide some experimental results from the implementation of our proposed schemes in Linux/RK, a "resource kernel" that supports reservations.},
        pages = {171--180},
        publisher = {IEEE},
        isbn = {0769514200},
        year = {2001},
        title = {Resource sharing in reservation-based systems},
        language = {eng},
        author = {de Niz, D and Abeni, L and Saewong, S and Rajkumar, R},
        keywords = {Real time systems ; Operating systems ; Multimedia systems ; Laboratories ; Power system protection ; Quality of service ; File servers ; Resource management ; Kernel ; Monitoring},
    }

    Also uses shared resource servers?



:bibliography:`systems, combined`
