=========================================================
 seL4 as a Protected Mode Platform for Real-time Systems
=========================================================

:Author: Curtis Millar

:Supervisor: Gernot Heiser
:Co-supervisor: Kevin Elphinstone

.. include:: ../utils.rst

.. Introduction to the topic

.. Building *safety-critical* real-time system using strong protection
   and a sound trust story.

.. Report structure:
    * Introduce a very minimal concpet of real-time that can be
      incrementally extended
    * For each extension describe:
       * Motivation
       * References to literature
       * How it incorporates into the model constructed by the report
       * How is it achieved by existing systems?
    * Given the above model, what is required of an RTOS & framework to
      be able to satisfy real-time systems developed with that model?

.. .. admonition:: To Do

   * Check for passive voice
   * Check for pulral first-person
   * Find locations which could be better expressed with supporting
     diagrams

Introduction
============

..
    * Real-time cyber-physical systems are becoming ever more prevalent
       * Medical, aerospace, automotive
    * Easier dedicate processing hardware for each real-time component
      for certification
    * Consolidate real-time components onto fewer physical processors
    * Use common off-the-shelf hardware components for real-time systems
    * Minimise verification cost with verified isolation of components
       * Isolate high-criticality components from low-criticality
       * Only need to verify high-criticality and shared components

Real-time cyber-physical systems are becoming increasingly prevalent in
situations where there is a great risk to human life and other valuable
assets in fields such as medicine, aerospace, and the automotive
industry. The security of lives and assets in these situations depend on
the correct operation of computer systems and failure of certain
components of these systems is intolerable. The work required to
guaranteed correct operation of these critical systems components can be
costly and time consuming; minimising the amount of the software that
requires a high-degree of assurance can save both time and money, and it
can also ensure that the greatest amount of focus is applied to the
components that most require it.

Many extant systems resolve issues of isolating non-critical
components from those which require high assurance by physically
separating their execution onto individual processors. In applications
which require minimisation of size, weight, and power consumption
(SWAP), this approach leads to increases in all three aspects of a
system, all of which lead to large increases in both initial and ongoing
costs. A substantially more cost-effective alternative is to consolidate
multiple real-time software systems onto a small number of physical
processors. This is only practical if the real-time and correctness
requirements of each individual system can still be guaranteed on shared
hardware.

In this project we will demonstrate that seL4 can be used as the
foundation of a wide range of real-time cyber-physical systems that can
reduce the overall cost of such systems by reducing the amount of
hardware required as well as by providing strong isolation guarantees to
reduce the amount of software that requires extensive verification. This
will be achieved by utilising a small trusted computing base to provide
the necessary guarantees of high-criticality software when that software
shares both hardware and software resources with lower-criticality and
low-assurance components.

This project builds on the work that produced seL4, a trustworthy
microkernel that has been proved to guarantee isolation of software
components, and the work from :cite:`Lyons:phd` to extend the seL4
microkernel with explicit concepts of scheduling and time that enable it
to guarantee the timing requirements of real-time software components.

.. What does this work build upon? (MCS)

.. Outline the other sections in the report

The remainder of this report will be structured as follows.
:chapterref:`background` will cover the background of real-time systems,
mixed criticality systems, and protected-mode kernels.
:chapterref:`related-work` will look at work related to consolidating
real-time systems into single physical systems and the construction of
mixed-criticality real-time systems. :chapterref:`scope` will discuss
the issues and scope of the project. :chapterref:`plan` will outline the
plan and timeline of the project.

Background
==========

Protected-mode microkernels
---------------------------

A *protected-mode* operating system kernel is the component of an
operating system (OS) that operates with greater access to hardware
mechanisms than all other software in the system. Hardware that provides
a greater *privilege level* at which a kernel can operate will also
enforce protections for software operating at levels of lesser
privilege. These protections prevent execution of privileged instructions
and access to all but the memory to which access has been
explicitly granted when unprivileged software is executing. When
unprivileged software attempts to violate these protections the hardware
*traps* the operation and invokes the kernel to respond to the fault.

A kernel operating in protected mode can construct isolated *threads* of
execution where execution of one thread has restricted access to read
from and write to a subset of the machine's physical and device memory,
respond to external events, and to invoke the kernel to perform work on
its behalf. When operating on behalf of a *user-level thread*, the
kernel can pass information between *protection domains* that would
otherwise isolate the threads from each other. This is used as the basis
for inter-process communication.

:cite:`Liedtke_95` characterises a *microkernel* by stating "a concept
is tolerated inside the |mu|-kernel only if moving it outside the
kernel, i.e. permitting competing implementations, would prevent the
implementation of the system's required functionality."

The L4 family of microkernels implement a minimal feature-set that
includes a threading construct, virtual addressing abstractions,
mechanisms for communication between threads, mechanisms for
communication with hardware, and capabilities that describe what
components of the system and underlying architecture any particular
thread may be able to access. All other operating system features are
implemented at user-level and are managed by software executing in
user-level threads.

.. figure:: microkernel.eps

   A comparison of the services that operate with full privilege in a
   microkernel and a monolothic kernel

A major advantage of microkernel-based systems is that a component is
not *implicitly* required to trust operating system components upon
which it does not depend. This bares a stark contrast to *monolithic*
kernels, where much of the operating system runs within the kernel at
its higher privilege level. In either system, any component is required
to trust anything that runs in at the kernel's privilege level as it has
unrestricted access to the entire system and the underlying hardware.

The concept of trust also extends beyond the code that runs at the
privilege level of the kernel; the *trusted computing base* of an
application is the set of all software and hardware that is required to
work correctly in order for the application itself function correctly.
If an application is highly critical then all the components in its TCB
are at least as critical as it is and require at least the same level of
guarantee. If the process of determining the guarantees of a highly
critical application is expensive, then it is desirable for that
applications TCB to be as small as possible.

:cite:`Klein_EHA_etal_09` presented seL4, a L4 microkernel with a
complete functional correctness proof. :cite:`Sewell_WGMAK_11` outline
the formal verification of enforcement of access control in seL4. The
formal verification proves that the kernel is guaranteed to correctly
isolate user-level components which makes seL4 a trustworthy basis for
safety-critical or security-critical systems.

Real-time systems
-----------------

Real-time computing systems are those with specific requirements
regarding the ordering, duration, and completion time of individual
operations. Such requirements are commonly necessary in control systems,
where the state of hardware needs to be maintained in response to
environmental changes and user input, multimedia applications, where
audiovisual information needs to be transmitted and synchronised locally
or over large networks, and digital signals processing, where large
amount of data must be processed with a high input rate. The physical
processing hardware used in such applications can also vary widely, from
low-power embedded microcontrollers to large multiprocessor systems
including processors dedicated to particular processing operations.

:cite:`Liu:rts` characterises real-time applications as a collection of
*tasks* and a set of *resources*. Each task is a sequence of *jobs* that
must be allocated some of the system's resources in order to complete.
A resource may be *finite*, where only a limited number of tasks can
access the resource concurrently, or *infinite*. Tasks are also
generally assumed to be *re-usable*, in that when one task is done with
it another task can be granted access.

Jobs within a task are often modelled with the following common
properties:

 * *release time* or *arrival time*; the instant after which a job may
   begin execution,
 * *deadline*; the instant at which the job must complete, and
 * *execution time*; the amount of time a particular job takes to
   execute.

For a particular task, we may not know some (or any) of the properties
of the individual jobs until execution time. Instead we determine the
bounds of all jobs within a task in order to reason about that task.

The *period* or *minimum inter-arrival time* is the minimum time between
the release of consecutive jobs. A task where the duration between the
release times of consecutive tasks is known a priori and is constant is
known as a *periodic task*. A task where only the *minimum* time between
consecutive releases is known is referred to as *aperiodic* or
*sporadic*.

The *worst-case execution time* (WCET) is the longest possible execution
time of any job within the task. This is generally determined by
analysis of the software with knowledge of the hardware that will be
used. A prediction of a WCET is useful only if it is sound, i.e. if it
is not less than the actual WCET.

Within a particular task, all jobs share a common set of properties,
namely:

 * the *relative deadline*; the maximum duration after the release of
   any job in a task within which the job must complete (this is often
   equal to the period of the task), and
 * the *laxity*; a function used to determine the degree to which a
   job is still useful if it misses its deadline.

Tasks are typically implemented within a real-time operating system
(RTOS) using operating-system threads with each job within the task
being a *release* of that thread by the operating system's scheduler.
This implementation does not permit more than a single job in any task
from executing at a time.  In order to allow a single task to operate
across multiple protection domains, some RTOSs separate scheduling
configuration from threads and release scheduling objects rather than
threads. The scheduling object can then be passed between the threads in
distinct protection domains that perform work on behalf of a job within
a task.

Task requirements
-----------------

The most fundamental requirement of the jobs is that they meet their
deadline. In a *hard* real-time task, every job within a task must
complete before its deadline. In a *soft* real-time task jobs may be
able to miss their deadline and still provide value to the system. This
can be characterised in a number of ways, such as allowing all jobs to
miss deadlines by a particular amount, allowing a fraction of all jobs
to miss deadlines, or for a cumulative total overrun not to be exceeded.

Each task also requires some subset of the system resources which are
both finite and reusable. Those resources must be available for any job
within that task to execute and those resources are acquired exclusively
while the job is using them.

Real-world systems are often composed of multiple interdependent tasks
where the result of a job in one task is a dependency of a job in
another. In this case, there is an *ordering* requirement between the
two tasks. Some requirements between tasks may also *weaken* execution
requirements. One such example may be when, within each period, only one
job from a set of tasks must execute at all.

Some soft-real time tasks may also be required to limit the variation in
the periods between the completion points of subsequent jobs. This
variation is generally referred to as *jitter*, and can cause some
external systems to behave sub-optimally. In other cases, a large amount
of jitter can be tolerated and there is a preference that every job
complete at the soonest possible time, producing lower *latency*.

System and environment requirements
-----------------------------------

Real-time systems also have a number of requirements of their
environment, including the physical hardware used and the software
responsible for co-ordination of the tasks on a particular processor.

If a system of tasks has been statically guaranteed to be schedulable
under the assumption that no task will ever execute for more than it's
pre-determined WCET, then any task that *does* exceed it's
pre-determined WCET can potentially prevent other tasks in the system
from satisfying their own timing requirements. To address this, the
environment must enforce *temporal isolation*, which ensures that no
task can prevent another from satisfying its requirements by
preventing every task from exceeding its configured budget (which is
usually no less than the expected WCET of the task).

The *correctness* of a particular task is also dependent on its state in
hardware remaining consistent. In order to ensure that no task can place
a another in an inconsistent state, the environment must ensure that no
task can modify the state of another without explicit authority, thus
ensuring the *integrity* of every task in the system. For real-time
tasks, the integrity of a task also includes the guarantee that it will
provided sufficient execution time for each job to complete before its
deadline. The state of some tasks may also contain privileged
information which other tasks must not be able to observe. An
environment must be provide sufficient *confidentiality* for particular
tasks to ensure the information is not leaked to an unprivileged task.
The requirements of integrity and confidentiality are not specific to
real-time systems, but are properties that pertain to any system that
must be reliable and trustworthy.

.. Add some reference to the cost of verifying software?

The *environment* which enforces these properties may be a static
process that is able to verify each component of the system to ensure
they cannot ever enter a situation where they violate such constraints.
While it provides a high degree of certainty, statically verifying
software to a sufficient degree is a process several orders of magnitude
more complex than that implementing the code to begin with and is very
costly as a consequence. A substantially more cost effective alternative
is to enforce these constraints at run-time using a combination of
hardware mechanisms (such as memory protection and hardware timers) in
co-ordination with a trustworthy monitor to respond to violations in a
way that still allows non-violating tasks to satisfy their requirements.

Scheduling
----------

A schedule must be chosen for a real-time system to determine when each
job in a task may be exclusively allocated finite resources. This is
particularly useful when assigning the use of a physical CPU for the
execution of a job. Different scheduling algorithms offer different
advantages and prioritise different functional requirements.

An admission test must be applied for a particular set of jobs when
paired with a particular scheduling algorithm. The test ensures
the algorithm will produce a schedule where the temporal requirements of
every task will be met, i.e., if every job in every task will be able to
execute to completion before its deadline. In cases where the real-time
parameters of every job is not known, every job is assumed to execute
with the worst case parameters of its task.

One can quantitatively compare scheduling algorithms using a number of
metrics. The *utilisation* of an algorithm refers to the proportion of
total system time which can be utilised by running tasks. More
pessimistic algorithms will only schedule tasks for a relatively small
portion of the available time. A schedule can also be compared by the
*latency* or *response-time* of the jobs that it schedules, i.e., the
time between a job's release and its completion. *Jitter* measures of
variance in latency for tasks of a given schedule.

Clock-driven
~~~~~~~~~~~~

A *clock-driven* schedule is prepared *offline*. It is set before the
system is run. It uses a static schedule of an entire *hyperperiod* of
tasks (the least common multiple of all task periods). The schedule
specifies when each task is selected to execute at any point in the
hyperperiod and can guarantee that each task will have time to execute a
job once in every period.

Such a schedule can provide greater control and knowledge ahead of time
of the pre-emption of tasks but can result in poor latency of aperiodic
and sporadic tasks. To address this issue, many clock-driven schedules
will admit sporadic and aperiodic tasks *online*, while the system is
running, and schedule them in the space not used to execute tasks in the
static schedule.

Priority-driven
~~~~~~~~~~~~~~~

*Priority-driven* scheduling algorithms provide a fully online
alternative to clock-driven schedules. Priority-driven schedules are
determined as the system is running and are able to adapt to the actual
execution time of jobs and the later release times of aperiodic jobs. In
doing so they can allow jobs to execute earlier to achieve lower total
latencies.  These algorithms can also account for tasks being added and
removed over the lifetime of the system by applying the admission test
at runtime.

Every job in a priority-driven schedule is assigned some numeric
priority. Whenever a job is released, the released job with the highest
priority is chosen to continue execution.  When a job is released that
has a higher priority than the currently executing job, the higher
priority job *preempts* the already executing job, with the higher
priority job executing to completion before the lower priority job is
resumed.

*Fixed-priority* scheduling algorithms assign the same priority to every
job within a task, allowing priorities to be assigned offline.
*Rate-monotonic scheduling* (RMS) assigns all jobs of a task the same
priority with the priority for a task being greater than the priority of
all tasks with a longer period. In a RMS schedule, jobs in a task with a
shorter period may preempt the jobs of a task with a longer period.
*Deadline-monotonic scheduling* (DMS) assigns priorities such that the
priority for a task will be greater than all tasks with a longer
relative deadline. In a DMS schedule, jobs in a task with a shorter
relative deadline may preempt the jobs of a task with a longer relative
deadline. In systems where the relative deadlines of all tasks are
proportional to their periods (i.e., the deadline is implied by the
period), the two algorithms are equivalent.

*Dynamic-priority* scheduling algorithms may change priorities of jobs
within the set of currently released jobs. One of the most common
dynamic-priority schedules is the *earliest deadline first* (EDF)
schedule. This assigns priorities to the released jobs in the order of
their absolute deadlines, such that the task with the earliest absolute
deadline at any given time has the highest priority.

Bandwidth-preservation
~~~~~~~~~~~~~~~~~~~~~~

A task is *bandwidth-preserving* if, at any instant, it will not
have been allocated a resource (such as a CPU) for more than a specific
proportion of the available time. The upper-bound on the proportion of
time used is the *utilisation* of the task. The utilisation of a
bandwidth-preserving server is described in terms of a period :math:`p`
and an *execution budget* :math:`b` where the utilisation is :math:`U =
\frac{b}{p}`.

A bandwidth-preserving server can be accounted for in a schedule as an
equivalent task of the same period and with the worst case execution
time equal to the execution budget. The bandwidth-preserving server will
never demand more execution time than the equivalent periodic task. This
allows tasks with no temporal sensitivity to be easily scheduled in the
in a real-time system.

Mixed criticality systems
-------------------------

:cite:`BuDa2019` describe criticality as "a designation of the level of
assurance against failure needed for a system component". A *mixed
criticality system* (MCS) is comprised of components of differing
criticalities. Examples of such designations include:

 * *safety critical*; wherein a component must be *guaranteed* against
   failure,
 * *mission critical*; wherein the operations of a component must be
   prioritised over less critical components, and
 * *non-critical*; where such components may be allowed to fail
   temporarily or completely.

The trusted computing base of any highly critical component is also at
least as critical as the component itself. This means that a
high-criticality component cannot depend on the correctness of a low
criticality component and must be properly isolated from all
lower-criticality and untrusted components.

Industry standards used to certify MCSs often provide a specific set of
such criticality designations, although they may refer to them by a
different name. Many real-world real-time systems are naturally mixed
criticality by their specification, as they must provide differing
levels of guarantee to different tasks.

Related Work
============

KeyKOS
------

The KeyKOS microkernel :cite:`Hardy_85` implements hierarchical
scheduling using *meters* to control delegation of execution time on the
CPU and *meter keys* which act as capabilities that confer access to
delegated execution time with which a *domain* can execute. All time
used via a meter key is tracked in every meter from the root to the
meter which produced the key. When the time associated with a meter key
is exhausted, the *meter keeper* is invoked to manage the delegation of
further time.

This system allows for a *meter keeper* to make scheduling decisions at
user level by judicious choice of when to grant access to processing
time.

Implementing a general-purpose real-time system using this microkernel
would require more complex user-level services to be created and would
impose a large overhead for the user-level operations required to
respond to scheduling events.

NOVA Microhypervisor
--------------------

The NOVA microhypervisor :cite:`Steinberg_BK_10` provides scheduling
contexts (SC) that encapsulate a priority level and a time *quantam*.
The time quantum describes the amount of time for which a thread may
execute before it is preempted by a thread of equal priority.

When a client thread performs a blocking call that is handled by a lower
priority server thread on the same core, the client donates the SC to
the server and the server executes using the SC of the client.  If a
second client with a higher priority than the first calls to the server
while the server is still processing the request of the first client,
the second client *helps* by allowing the server to run with its
higher-priority SC. A server will always run with the highest-priority
SC of all of its blocked clients.

While this system may be useful in limiting *priority inversion*, when
work on behalf of a low-priority task prevents the progress of a
high-priority task, it does not provide the bandwidth or scheduling
guarantees of a system with hard real-time components nor does it
provide any level of temporal isolation between components.

Composite
---------

The Composite microkernel :cite:`Parmer_West_08, GaPaPa2020` makes a
wide variety for schedulers possible at user-level. *TCaps*
:cite:`Gadepalli_GBKP_17` are temporal capabilities that control
explicit access to execution time on a particular CPU. They provide a
single finite amount of time at a particular global priority. A
user-level scheduler can construct access to multiple instances of time
to implement recurring releases of a thread with a TCap for each
release. As each TCap has an associated global priority, distinct jobs
within a task can be assigned different priorities if they are released
using distinct TCaps.

Composite uses a migrating thread model for IPC. When a thread executing
in one component calls into another component, the thread context is
migrated to the called component for the duration of the call. This
allows a TCap to remain associated with a thread when it calls into
another component with that component still executing time on the
original thread's TCap.

Priority inversion can be minimised in Composite with TCaps using
user-level scheduling operations. When a resource within a component is
locked and a client with a greater priority requests access, it can
communicate with the scheduler component to allow the thread with
exclusive access to continue execution using the TCap with the highest
priority of all clients waiting to access the component.

Utilising this system requires complex user-level components to
implement the scheduling decisions and handle scheduling events which
add to overhead and implementation complexity. Each scheduling operation
also imposes a considerable cost as it includes a switch to a dedicated
thread execution within a scheduling component.

Quest-V Hypervisor
------------------

:cite:`Danish_LW_11` utilise the sporadic server model described by
:cite:`Stanovic_BWH_10` to implement real-time scheduling for
virtual-CPU contexts in the Quest-V hypervisor. All tasks are executed
using a *Main VCPU* context which is scheduled using the algorithms from
:cite:`Stanovic_BWH_10`. When a task needs to perform an I/O operation
with an external device, it communicates with a driver on an *I/O VCPU*
which is responsible to directly communicating with hardware. Each I/O
VCPU is scheduled with minimal logic to preserve bandwidth. When an I/O
VCPU handles a request from a Main VCPU, it inherits the priority of the
Main CPU until the request is complete.

:cite:`Danish_LW_11` note that the overheads from the complexity of the
sporadic server implementation have a noticeable impact on throughput
and that the I/O VCPUs benefit from the simplified bandwidth
preservation logic.

This demonstrates how a scheduling system built on bandwidth constrained
scheduling contexts can be made effective but it does not address
scenarios where tasks of differing criticalities must share hardware and
software resources.

Flattening hierarchical mixed criticality scheduling
----------------------------------------------------

:cite:`Volp_LH_13` describe a way in which a system of temporally
isolated real-time tasks, encapsulated with *scheduling contexts*, can
be used as the basis for a hierarchical system of independent real-time
components. They also describe how different scheduling algorithms may
be mapped onto such a system of scheduling contexts and what
modifications may be required to adapt the scheduling contexts to allow
for different algorithms.

They introduce a system where a task is represented by a *scheduling
context* (SC), a kernel object which can be released by the operating
system scheduler, which is attached to the thread responsible for
executing in response to a job being released in a task. Each scheduling
context is given a priority, with the highest released SC being executed
at any given time. Each scheduling context may be used for execution up
to its assigned budget in each window of time equal to its period. Each
SC is also assigned a fixed criticality level.

They extend these fixed-priority SCs with additional behaviour
that is required for particular mixed criticality scheduling algorithms.
Scheduling contexts are extended with a relative deadline which is used
to determine when a job has not completed by its deadline and preempt it
in such a case. They also allow a task to execute with a series of SCs
with each SC describing a single job. This is done for every job in the
systems hyperperiod. The scheduler may also enable or disable
scheduling contexts, ensuring that they are not allocated resources in
exceptional cases).

Each of the changes increases the applicability of the underlying model
to allow a greater set of single and mixed criticality scheduling
algorithms to be implemented on top of the primitives of the model.

While this system does show the flexibility of the underlying
primitives, the guarantees to real-time tasks depend entirely on the
correctness of every scheduling component within the system. This work
does not include the necessary mechanisms to adequately enforce temporal
isolation such that untrusted and low-criticality tasks cannot interfere
with the correct operation of high-criticality tasks.

MC-IPC
------

:cite:`Brandenburg_14` describes a system of encapsulating shared
resources in *resource servers* and describes a protocol, *MC-IPC*, for
communication between tasks of varying criticality that preserves
'temporal and logical isolation'. This allows for the effective use of
resources shared between tasks of differing criticality. The protocol
implements a priority inheritance that is fair across multiple cores.

The system reduces the assurance burden and the level of trust required
of low-criticality tasks that share resources with high-criticality
tasks. Resources shared between components of differing criticality and
assurance by encapsulating them in a shared resource server that
inherits the priority and execution time of its highest priority
client.

The protocol requires all tasks provide sufficient time for all lower
priority tasks on all cores that have been granted access to the server
to complete their request. This ensures that even when a lower-priority
task is able to access the server ahead of a high-priority task, the
lower-priority task cannot prevent the use of the server from the
high-priority task by exhausting its available budget while the server
is responding to it. This also ensures that in a schedulable system, all
real-time tasks will have all of their requests serviced by the shared
resource server, such that even high-criticality tasks with low priority
will be able to complete.

The protocol makes two fundamental assumptions about the scheduler to
which it is applied. The first is that reservations of the highest
priority level that have available budget may be selected for execution
and may thus have their time consumed, even when the thread executing
on the reservation is inactive or blocked on IPC. The second is that the
priority of a reservation does not change until its budget has been
exhausted or replenished.

.. This protocol is definitely incompatible with seL4/MCS as neither
   assumption holds. Either seL4/MCS needs to be changed such that it
   does hold (effectively requiring a complete re-engineering of the
   implementation) or an equivalent technique needs to be identified.

.. It seems that the requirement on priority doesn't actually need to be
   so strong, simply ensuring that the priority of the server is higher
   than that of the enqueued threads and that the priority of threads
   does not change while they are in the queue may be sufficient. The
   charging of time to a particular SC is more complicated though, not
   helped by the strict bandwidth constraint.

This work effectively demonstrates how resources can be shared between
mixed-criticality tasks using priority inheritance without preventing
the correct execution of high-criticality tasks. As such, it would be
useful component of a more complete real-time operating system. However,
it makes assumptions that restrict the operating system in which it
operates: a server is tightly coupled the IPC medium used to request
service such that it is always aware of all blocked clients and the time
the server spends executing can be charged to any one of its blocked
clients.

seL4 mixed criticality scheduling
---------------------------------

:cite:`Lyons:phd` presents a modification to the scheduler used by seL4
microkernel, enabling the construction of mixed criticality real-time
systems. It introduces explicit scheduling context objects that
represent access to processor time which can be managed at user-level.
These changes allow for a number of real-time scheduling decisions to be
made with user-level components.

A thread must have access to a SC with available budget in order to
execute on a CPU. Each SC is bound to a particular CPU core and enforces
a maximum bandwidth by replenishing a particular amount of time
throughout a given window of time. This ensures that, at any instant,
the amount of CPU time that may have been consumed by threads associated
with an SC does not exceed a configured portion of all time equal of its
*budget* divided by its *period*. Only the threads of the highest
configured priority that are not blocked and with a *released*
scheduling context are eligible for execution. Time from a scheduling
context's available budget is only consumed when it is associated with
the currently executing thread.

In addition to the changes to scheduling, the semantics of blocking IPC
is changed to guarantee that whenever there is more than a single TCB
waiting on a kernel object to send or receive IPC, the thread with the
highest priority will always perform its operation first.

When a thread exhausts it available execution budget or loses access to
a scheduling context a user-level monitor is able to respond and
reconfigure the task such that it can be recovered. This allows for
management of soft real-time tasks and low-criticality tasks and enables
the monitor to recover resource servers shared between mixed criticality
clients.

Scope
=====

This project aims to investigate the process of building
mixed-criticality real-time systems on consolidated hardware using the
seL4 microkernel along with the changes provided by :cite:`Lyons:phd`.
This work will include demonstrating how independent real-time systems
and non real-time software can be scheduled on common hardware while
ensuring that they are temporally isolated from each other as well as
demonstrating communication and sharing of resources without violating
temporal guarantees. We will also investigate various approaches for
recovery of low-criticality tasks and shared resources and determine how
various techniques can be used without violating the requirements of
high-criticality components.

In addition to the investigation of the practicality of this kind of
system construction, we will also investigate what properties the
real-time operating system, including the kernel and any root-level
admissions control, must verifiably guarantee such that highly-critical
components can also be guaranteed to operate correctly.

At the end of this project, we will review the approaches used and the
requirements identified to determine how robust a real-time operating
system satisfying these requirements is and what limitations apply to
systems constructed using the methods investigated.

The systems investigated by this project will be limited to single-core
processors; multi-core are not within the scope of the project. Whilst
the approaches resulting from the work in this project could be used to
satisfy the real-time requirements in many industry standards,
demonstrating compliance with these standards is also beyond the scope
of this project.

Plan
====

System analysis tools
---------------------

In order to determine the efficacy of the components being built over
the course of this project and analyse the impact of changes to any
existing components, we will produce a collection of tools to trace the
scheduling and IPC operations in a system as well as tools to analyse
and compare these traces. These will build on existing work for tracing
kernel operations in seL4 and tracing and analysing scheduler operations
in seL4 :cite:`Holzapfel:be`.

These tools will need to be able to track events on IPC objects
(endpoints, notifications, and reply objects), and associate IPC and
scheduling operations with threads and scheduling contexts. These traces
can then be used to describe individual tasks and shared resource
servers to determine the behaviour of system components. This will also
allow for analysis of common metrics for benchmarking including
processor utilisation, throughput, and response latency and jitter.

..  Prepare tools to analyse behaviour of real time system:

   * Logging of the scheduler, interrupts, and task completions
   * Must not rely on root-level scheduler for logging for comparisons
   * CPU utilisation
   * Secheduler admissions & configuration
   * Measuring throughput and latency
   * Make sure that this is painless to update and re-use for the
     remainder of the project
   * Determine reference workloads to demonstrate effects in throughput
     and latency

.. * How do you demonstrate a real-time system is functioning as
     expected?
   * How can you analyse its behavior?
   * How can you measure the performance of a real-time system?

Root-level admission control
----------------------------

.. .. note::

   Root-level admission test must enforce rate-monotonic schedule which
   ties the periods of tasks to the priorities and also limits the
   selection of priororities that may be admitted.

A root-level admissions control component will be created to allow
mutually distrusting components to schedule on a shared processor. This
component will be responsible for ensuring that any scheduling context
it produces is guaranteed a *minimum* bound on its execution. It does so
by considering the worst-case pre-emption behaviour of all of the
real-time scheduling contexts and accounting for all time that would be
spent on involuntary context-switches for each admitted SC.

In order to bound sources of external pre-emption, it will associate any
external interrupt with a trusted thread operating on a single SC. Each
interrupt will only be accepted once in any period of its SC.

For static systems, this component can be replaced with the same check
performed offline at system-design time, such that the static system is
configured with an admissible set of SCs. Dynamic systems require a
trusted admissions control component to perform this admissions test on
request.

.. This is the trusted scheduler for all subsystems. No subsystem should
   need to trust other subsystems unless they have a direct dependency
   on them.

    * Identify what the root-level scheduler must guarantee
    * Responsible for global admissions test and lower-bound guarantees
    * Rate-limiting IRQs (force IRQs to be handled by a proxy
      periodic task which will only every respond to one IRQ per
      period).
    * How to rate limit IPIs and interference from other cores?
      (probably out of scope)

.. Add stall invocation on SC which pushes all refills so that the head
   refill starts at n us. Alternatively, allow an SchedControl to
   provide system time and allow for stalling until a specific time.
   Should allow current SC to stall.

.. Add a periodic/job budget to SC. Whenever an SC yields, the remaining
   periodic budget is charged to the current SC and the job budget is
   reset.

Alternate scheduling in subsystems
----------------------------------

To demonstrate that different systems can be scheduled using independent
scheduling algorithms, as suggested by :cite:`Volp_LH_13`, we will
implement a specific dynamic-priority scheduling algorithm by having a
control component with performs priority assignment and task selection
at user level. :cite:`Lyons:phd` has already shown a simple case where this
could work using seL4 alone. To show that this can be done separately
for each subsystem, this will only depend on the guarantees provided by
the kernel and the root-level admissions control component.

.. Demonstrate that each subsystem can define their own internal
   scheduling mechanism mased on the root scheduler using in the manner
   of :cite:`Volp_LH_13`.

    * Static fixed-task priority subsystem
    * Tasks with dynamic job priorities
    * Adaptive mixed-criticality (responding to low-criticality tasks
      exceeding WCET estimates)
    * Earliest deadline first & greedy priority algorithms
    * Try and demonstrate one or two exemplary scheduling algorithms
      rather than all of them.

With some of the scheduling decisions being made at user-level, the
impact of time spent in the user-level scheduler both in terms of its
general additional overhead and its impact on schedulability will be
assessed to determine the feasibility of this approach.

In order to implement this scheduler it is likely that changes will need
to the API for scheduling contexts. In particular, in may be required to
extend SCs such that they can be delayed to arbitrary points in time,
and they may require some explicit notion of a deadline and
non-bandwidth-limiting period. The impact of these changes will be
benchmarked and used to evaluate the efficacy of the changes and to
determine where possible optimisations could be added.

.. :cite:`Volp_LH_13` suggests that changes will need to be made to SCs
   in order to support a wider range of behaviours for different
   scheduling algorithms. May not be the same as those described in the
   paper. What overheads do these changes add?


.. * Scheduling decisions made at user level
   * Using user level scheduler for pre-emption
   * Addition proxy task for rate limiting of IRQs
   * Rate limiting of communication between cores (probably out of
     scope)

Soft-real time recovery
-----------------------

Soft-real time tasks are those that can accept some cases of deadline
misses. In some cases these tasks can be allowed to execute past a
deadline or they can be forced to abort a particular job so that they
can be ready for a subsequent release. In order to implement these
tasks, some sort of mechanism for responding to a missed deadline and
restoring the state of the task must be demonstrated. Depending on the
desired behaviour, this can include allowing the task to continue
execution (at a potentially different priority) or creating a checkpoint
to which a task can be reset. Both of these strategies will be
demonstrated in the system presented.

Shared resource servers & recovery
----------------------------------

.. .. note::

   seL4/MCS uses priority ceiling for shared resource servers to
   guarantee that a low-priority task doesn't prevent progress of a
   higher-priority task. Only real issue is guaranteeing enough time or
   recovery for lack of time. Perhaps include time for full recovery in
   WCET & only reset thread enough to receive next donated SC.

A resource server encapsulates a resource shared between multiple tasks.
It is implemented as a thread that accepts donated SCs from its clients.
It must guarantee that a *low-criticality* task cannot interfere with
the correct execution of a *high-criticality* task when both are clients
to the task. If a low criticality task exhausts its budget or withdraws
its donated SC from a shared server, that server must be able to recover
and maintain availability with all other tasks. The time taken to
perform this recovery must also be accountable within the scheduling of
the entire system.

The mechanics for returning a shared resource server in the case that it
loses access to execution time are similar to the recovery mechanisms
for soft real-time tasks. Ensuring that the time taken to recover a
shared resource server is accounted for is a different challenge. It may
be possible to include recovery cost in the worst case execution time
for a resource server and charge recovery to the subsequent client. It
may also be possible to prevent clients from requesting a service until
they have sufficient time. We will investigate both of these approaches.

.. Implementation of shared resource servers with temporal isolation
   guarantees. :cite:`Brandenburg_14` will be a strong reference for this
   component.

   Recovery of shared resources when a server exceeds the provided
   budget, must not violate temporal isolation.

A real-world real-time system
-----------------------------

We will build a real world system will to demonstrate the application of
the theoretical real-time systems primitives developed during this
project to the construction of real-world systems. The target system
will be based on a existing quad-copter system
:cite:`Cofer_GBWPFPKKAHS_18` work that will be extended to comprise a
realistic mix of mixed criticality and shared components.

The high-criticality subsystem will be the flight control system. The
low criticality component will be a low-latency media stream
(potentially a video feed). Both components will share access to a
common telemetry component to collect and report the status of the
system.

This system will demonstrate the schedulablity of such a mixed
criticality system and show that the guarantees of the high-criticality
components can be satisfied in a system that is shared with
low-criticality and non-critical components.

.. Demonstration with a real-world mixed-criticality system

    * Must have hard real-time high-criticality components
       * Control system?
    * Must also have high-priority low-criticality components
       * Multimedia or I/O operations?
    * Shared resources between high and low criticality components
    * Also include best-effort subsystem that is non-critical and not
      real-time.
    * Demonstrate that real-time requirements are met for tasks

.. Timeline:

   20T2, 20T3, & 21T1

   * Tooling will probably be several weeks but can start before the end
     of 20T2
   * Root level scheduler work will probably be a few weeks. COuld be
     done in tandem with analysis tooling.
   * A few weeks will be needed to implement the alternate scheduling
     and changes to seL4.
   * If I've done everything right at this point the analysis of the
     seL4 changes shouldn't be too hard.
   * Building comparative systems that do and don't use heirarchical
     scheduling may be hard. Probably several weeks.
   * Soft real-time recovery part should not take long.
   * Shared resource servers may likely be the most difficult part, will
     need a lot of discussion with Bjorn. Should probably prepare half a
     term.
   * Real-world system should probably have half a term reserved for it


.. figure:: timeline.eps
   :width: 17cm

   Proposed timeline for thesis project
