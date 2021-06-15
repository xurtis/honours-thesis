================================================================
 Guaranteed response time for mixed-criticality systems on seL4
================================================================

:Author: Curtis Millar

:Supervisor: Gernot Heiser
:Co-supervisor: Kevin Elphinstone

.. include:: ../utils.rst

Introduction
============

.. Set up context

Computerised systems are widely used in situations where the security of
lives and assets is paramount and where the systems have strict timing
requirements for how they must interact with each other and with the
physical world. The level of assurance required for these
mixed-criticality real-time systems demands precise guarantees to
demonstrate that the timing requirements for any highly critical
components are always met. The cost of formally and mathematically
verifying these guarantees is immense and grows exponentially with
system complexity and is in tension with the desire to consolidate the
software of such systems into fewer hardware components, particularly in
applications which must minimise size, weight, and power consumption
(SWaP) of the physical system.

In this thesis, we demonstrate an approach that provides the required
guarantees utilising seL4, a verified protected-mode microkernel, to
enforce the scheduling behaviour required for high-criticality
components without needing to perform any verification or provide any
level of assurance for low-criticality components. This approach
drastically reduces the cost of providing absolute assurance of
real-time systems used in medical, aerospace, automotive, and military
applications.

This project will outline a number of changes made to the seL4
microkernel, ensuring that it enforces scheduling behaviour precisely
and correctly, and then it will demonstrate how those guarantees are
used to construct real-time systems with highly-critical components that
will always satisfy their real-world timing requirements.

.. Guarantee? Formal verification? real-time system? mixed-criticality?

.. Goals of project

.. ----

.. What are the goals?

.. Use seL4 to enforce any necessary bounds for scheduling analysis to
   be able to guarantee that all job deadlines for hard realtime tasks
   are met in mixed-criticality systmes.

.. What are real-time requirements?

.. What are mixed-criticality systems?

.. What is the value in the guarantees offered by seL4?

.. Scope (single-core systems, fixed-priority scheduling)

.. What are the real-world contexts and use-cases of such systems?

.. Consolidate real-time systems onto fewer hardware components (fewer
   falible components & lower costs) for more computerised control
   systems

.. Minimise verification requirement

.. takeaway paragraph


The remainder of this report will be structured as follows.

 * :chapterref:`background` will cover the background of real-time
   systems, mixed criticality systems, and protected-mode kernels.

 * :chapterref:`related-work` will look at work related to consolidating
   real-time systems into single physical systems and the construction
   of mixed-criticality real-time systems.

 * :chapterref:`response-time-analysis` will introduce the concept of
   response time analysis and its use in determining the schedulability
   of high and mixed-criticality real-time systems and the requirements
   imposed on the scheduler implementation.

 * :chapterref:`sel4` will introduce seL4 as a protected-mode
   microkernel with extensions to guarantee scheduling behavior for
   mixed-criticality real-time systems.

 * :chapterref:`approach` will outline the approach taken to adapt the
   extensions in seL4 to the theory of response time analysis and
   demonstrate how seL4 can be used to guarantee schedulability of
   mixed-criticality systems.

 * :chapterref:`implementation` will outline the implementation of the
   changes made to seL4 to guarantee scheduling properties of system
   components and the guidance of applying time demand analysis to
   real-time systems on seL4.

 * :chapterref:`evaluation` will review the efficacy of the
   implementation and strategy to show that the system does provide the
   guarantees necessary for mixed-criticality systems in all contexts.

 * :chapterref:`future-work` will outline direction for future work to
   build on what has been discussed and implemented.

 * :chapterref:`conclusion` will conclude the work of this thesis.

Background
==========

.. Provide enough detail here that can be omitted in subsequent sections
   for anyone with prior knowledge bet that can ensure those without
   domain knowledge can understand the rest of the document.

   Allow back-references for anyone that skipped.

   Don't refer to anything before it has been formally introduced

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

.. What characterises a kernel?

.. What makes a microkernel distinct from other kinds of kernels
   (unikernels, monolithic kernels)? (minimality)

.. What are the benefits and limitations of a microkernel?

.. Only the kernel executes in a protected mode (with full access to
   modify the system)

.. Kernel can delegate system-level responsibilities to user-mode
   software

.. Kernel does not depend on correctness of user-level software

.. Kernel enforces isolation mechanisms between user-level components,
   prevents fault propogation where there is not dependency

Formal verification
-------------------

Formal verification of software is a process whereby the implementation
of that software is said exhibit the same behaviour as the specification
of that system. Where the implementation may exhibit a potentially
greater set of behaviours than the specification, the implementation is
said to *refine* the specification. The refinement process generally
requires a relation to be made between the formal semantics of some
representation of the implementation, such as the source code or the
binary machine code, and the possible behaviours of the specification.

Additionally, or alternatively, formal verification of software may be
the process of proving that certain the specification (or the
implementation) satisfies certain, formally defined properties.

.. What characterises formally verified software?

.. To what degree can software be formally verified?

.. What are the benefits and limitations of formally verified software?

.. How does formal verification relate to software assurance?


.. takeaway paragraph - background

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
access the resource concurrently, or *infinite*. Resources are also
generally assumed to be *reusable*, in that when one task is done with
it another task can be granted access.

Jobs within a task are often modelled with the following common
properties:

 * *release time* or *arrival time*; the instant after which a job may
   begin execution,
 * *deadline*; the instant at which the job must complete,
 * *execution time*; the amount of time a particular job takes to
   execute, and
 * *blocking time*; the amount of time for which a particular job is
   preempted by execution other than that of higher-priority tasks.

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

The *worst-case blocking time* is the longest possible time any task may
be preempted by execution other than that of higher priority tasks. This
is determined by any non-preemptable operations, such as privileged
operations that modify privileged state, and priority inversions, where
tasks are able to preempt other tasks with a higher priority.

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
across multiple protection domains, i.e. in contexts with different
access control restrictions, some RTOSs separate scheduling
configuration from threads and release scheduling objects rather than
threads. The scheduling object can then be passed between the threads in
distinct protection domains that perform work on behalf of a job within
a task.

.. What characterises a real-time system?

.. In what contexts are real-time systems used?

.. How can real-time systems and tasks vary?

.. hard real-time

.. soft real-time

.. How are real-time systems defined formally?

.. tasks, jobs, and resources

.. deadlines, activations, execution time, inter-arrival time / periodicity

.. aperiodicity

.. CPU as a resource

Real-time scheduling algorithms
-------------------------------

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

.. What must a real-time scheduling algorithm do?

.. What characterises a scheduling algorithm?

.. How do scheduling algorithms vary?

.. What benefits are provided by different varaitions?

.. Generally, what are they?

Priority-driven scheduling algorithms
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Priority-driven schedules are determined as the system is running and
are able to adapt to the actual execution time of jobs and the later
release times of aperiodic jobs. In doing so they can reduce the time
between the release and completion of a job if higher priority tasks
don't consume their full WCET. These algorithms can also account for
tasks being added and removed over the lifetime of the system by
applying the admission test at runtime.

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

.. What characterises a priority based scheduling algorithm?

.. How can they differ?

.. What are the benefits and limitations for different variations?

.. Dynamic vs. fixed

..
    Rate-monotonic scheduling
    ~~~~~~~~~~~~~~~~~~~~~~~~~

.. What characterises RM scheduling

.. In what ways is it similar & different to other scheduling
   algorithms?

.. What are its benefits & limitations

..
    Deadline-monotonic scheduling
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. What characterises DM scheduling

.. In what ways is it similar & different to other scheduling
   algorithms?

.. What are its benefits & limitations

..
    Admissions tests
    ~~~~~~~~~~~~~~~~

.. What is the purpose of an admissions test

.. How can we guarantee a given scheduling algorithm will always allow
   all hard realtime tasks to always complete before their deadline

Sporadic servers
~~~~~~~~~~~~~~~~

:citet:`Sprunt_SL_89` present *sporadic servers*, a model of a task that
that may not have hard realtime requirements or any notion of jobs, but
that is bounded by the worst-case behavior of a fixed-priority aperiodic
task. A sporadic server can be considered as the equivalent aperiodic
task for all timing analysis purposes.

A sporadic server is assigned a *period*, *budget*, and a priority,
which are respectively the same as the minimum inter-arrival time,
worst-case execution time, and priority of of the equivalent aperiodic
task. The sporadic server is scheduled as though it is an infinite set
of aperiodic tasks, each of which has a worst case inter-arrival time
equal to the period of the sporadic server and a priority equal to the
sporadic server. The worst-case execution time of each task in the
infinite set is infinitesimally small, but the sum of the worst case
execution times is equal to the budget of the sporadic server.

In a fixed priority system of aperiodic tasks, the worst-case
interference from a set of tasks with an equal priority and minimum
inter-arrival time and with a known combined worst-case execution time
is equal to the interference produced by a single aperiodic with the
same priority and minimum inter-arrival time and with combined
worst-case execution time.

When a sporadic server executes, it can only consume as much time as the
total WCET of *released* tasks from the equivalent infinite set of
tasks, i.e., only those tasks for which it has been more than the period
since they last executed. Unlike an aperiodic task, when a sporadic task
suspends no execution time is forfeited. A subset of the tasks with a
combined WCET equal to the time the sporadic task spent executing are
considered has having their jobs completed and are scheduled for future
job execution. If this is less than the total WCET of all tasks that
were released before execution began, the rest of the tasks remain
released and allow the task to execute immediately when it is resumed or
becomes unblocked. The key to scheduling sporadic tasks as an infinite
set of tasks is that we only determine which task in the infinite set
were released once the server suspends. We only consider enough tasks to
have been released so as to cover the execution cost.

This model is useful for scheduling soft realtime, non-realtime, and
low criticality tasks in a system of hard realtime and high criticality
tasks, i.e. a mixed-criticality system, without restriction on the
scheduling properties of any tasks.

Shared resources
----------------

.. What characterises a shared resource?

.. What problems do shared resources present?

.. How are the problems with shared resources resolved?

..
    Shared resource protocols
    ~~~~~~~~~~~~~~~~~~~~~~~~~

Tasks in a real-time system may require access to a common set of
resources, with some of those resources only being usable by a limited
number of tasks at a time. In order to ensure that only one task has
access to an instance of any resource at a given time, a resource access
protocol is applied to the schedule of a real-time system. The protocol
provides imposes a set of requirements on how resources are considered
in the schedule and provides a set of guarantees regarding the timing of
each resource access.

The *immediate priority ceiling protocol* is a resource access protocol
for fixed-priority scheduling algorithms. It assigns a priority to each
resource, one that is higher than the priority of all tasks that may
access that resource. When a task executes, it operates at the highest
priority of all those assigned to the resources to which it has obtained
exclusive access. If it does not have exclusive access to any resources,
it operates at its own priority. This ensures that the task will always
complete any access before any task at a lower priority than the
resource would begin execution of a job. As such any task that may wish
to access a resource is guaranteed immediate access to all resources it
may require once execution for a job commences. If the job of any
higher-priority task were to preempt it before it accesses a certain
resource, that preemption, including all resource accesses, would
complete before the task could continue execution. Additionally, all
resource access from lower-priority tasks must complete before the job
can begin execution as such accesses occur at a higher priority than the
task.

.. What characterises a shared resource protocol?

.. How can they differ?

.. What are the benefits and limitations associated with the differences

..
    Immediate priority ceiling protocol
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. What are the characterstics of the PCP?

.. In what way is it similar & different to other algorithms?

.. What are the benefits & limitations?

.. Benefits? (If you're executing then you're guaranteed to get the
   resource without blocking without) (No need for bandwidth donation)

..
    Shared resource servers
    ~~~~~~~~~~~~~~~~~~~~~~~

.. What characterises a shared resource server?

.. What problems do shared resource servers resolve?

.. An implementation of a shared resource

.. Model the resource as a distinct OS thread which assumes
   higher-priority execution while the resource is acquired

.. One thread per reasource

.. Forces hierarchical resource acquisition preventing deadlocks

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

.. What characterises a mixed-criticlaity system?

.. What is meant by 'criticality'?

.. How does criticialtiy relate to assurance?

.. What are the problems present in mixed-criticality systems?

.. Differing levels of criticality of different tasks and components

.. Differing levels of assurance

.. Criticality and assurance requirement is transitive across resource
   servers

.. Criticality and assurance level is independent of task priority

.. Criticality and assurance is not transitive to resource server
   clients

Reservation-based schedulers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Reservation-based schedulers offer a mechanism to enforce the execution
bounds assumed by any timing analysis for a real-time system, rather
than either formally verifying the implementations of tasks to show that
they do not exceed those bounds or simply assuming that they do not.

Each task in a reservation based system is represented by a
*reservation*. The reservation is controlled by some scheduling
component and encapsulates time that is made available for execution
associated with the task. When the available time associated with a
reservation is depleted, the scheduler is invoked to suspend execution
associated with the task and schedule more time to be made available in
the future.

Only the portion of the system implementing and scheduling reservations,
in addition to any part of the system that is entirely non-preemptable,
can produce violations of the scheduling assumptions; every other part
of the system is forcibly bounded to operate within the configured
schedule. As such, only the implementation and scheduling of
reservations and non-preemptable code sections need to be verified to
show that tasks are *temporally isolated*, i.e., that a change in
behaviour of one task can prevent another from satisfying its timing
requirements.

.. What characterises a reservation-based scheduler?

.. How does it address the issues present in mixed-criticality systems

.. Enforce execution within a limited time demand through reservations

.. Reservations are passed to resource servers such that they may
   execute with the time of the client

Related work
============

.. Why are these relevant?

.. Why are these distinct from the problem we are solving?

.. Why are these insufficient to solve our problem?

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
single finite amount of time at a particular global priority. Components
within Composite encapsulate a set of access controls, such as accesses
to system resources and physical memory, and implementation of a set of
routines that can execute within it. A user-level scheduler can
construct access to multiple instances of time to implement recurring
releases of a thread with a TCap for each release. As each TCap has an
associated global priority, distinct jobs within a task can be assigned
different priorities if they are released using distinct TCaps.

Composite uses a migrating thread model for IPC. When a thread executing
in one component calls into another component, the thread context is
migrated to the called component for the duration of the call. This
allows a TCap to remain associated with a thread when it calls into
another component such that time spent execution in that component still
executing time on the original thread's TCap.

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
which is responsible for directly communicating with hardware. Each I/O
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
systems hyperperiod, the least common multiple of the periods of all
tasks in the system.

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
tasks. Resources are shared between components of differing criticality
and assurance by encapsulating them in a shared resource server that
inherits the priority and execution time of its highest priority client.

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

This work effectively demonstrates how resources can be shared between
mixed-criticality tasks using priority inheritance without preventing
the correct execution of high-criticality tasks. As such, it would be
useful component of a more complete real-time operating system. However,
it makes assumptions that restrict the operating system in which it
operates: a server is tightly coupled to the IPC medium used to request
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

The bounds on execution are too strict to be applied to
mixed-criticiality and hard realtime systems without losing any notion
of temporal isolation. Additionally, there are issues regarding the
accounting of kernel execution time. These issues are explained and
resolved in the remainder of this thesis.

.. takeaway paragraph - related work

Response Time Analysis
======================

.. Set up context / problem?

.. Need to have RT background at this point

   * What is a real-time system?
     * A set of real-time tasks
     * Real-time tasks is a set of jobs
     * Non-RT tasks must be scheduled as though they are RT
       - Treat unblocking/resume operations as job releases
       - Treat blocking/suspending operations as completions

The timing analysis of a real-time system determines whether or not that
system will, under all circumstances, satisfy its expected timing
behaviour. Any timing analysis will make assumptions regarding the
behaviour of each job of each task in the system. To ensure that we
guarantee the results of the timing analysis, we must determine these
assumptions and guarantee they hold, either by verification of the tasks
themselves or by enforcing them in a scheduling monitor. As we will see,
the scheduler must enforce specific guarantees regarding how execution
time is made available to a task at a given priority, how that execution
time may be consumed by a resource at a higher priority, and how unused
execution time is lost.

:citet:`VestalS1994Fsaf` presents a process that has come to be known as
*response time analysis* (RTA) that produces a critical scaling factor,
the maximum factor by which the execution time of all tasks can be
scaled without loss of schedulability. While :citet:`VestalS1994Fsaf`
details further ways in which this analysis can be used to adjust a
system and account for variability, we only seek to demonstrate the
bounds that must be enforced for the analysis to apply.

To determine the schedulability of a task set we must first produce some
mathematical model of that task set. We describe a set of tasks as
:math:`\left \lbrace \tau_{1}, \tau_{2}, \dots, \tau_{n} \right \rbrace`
where each task :math:`\tau_{i}` has an assumed worst-case execution
time :math:`C_{i}`, a known minimum inter-arrival time :math:`T_{i}`,
and some fixed priority :math:`P_{i}`. We also assume a worst-case
blocking time, :math:`B_{i}`, which is the worst-case amount of
interference time from sources other than tasks with an equal or higher
priority, which can include lower-priority tasks accessing resources
shared with tasks at an equal or higher priority. For each task, we also
consider the set of task indices at an equal or higher priority,
:math:`\mathbf{H}_{i} = \left \lbrace x \, \middle | \, P_{x} \ge P_{i}
\right \rbrace`.

To produce a potentially large overestimate of the worst-case response
time :math:`R_{i}`, for a given some task :math:`\tau_{i}`, we assume
that all tasks at an equal or higher priority execute for their worst
case execution times as many times as they may be released in the
minimum inter-arrival time of :math:`\tau_{i}`. We also assume that the
worst-case blocking time :math:`B_{i}` is also observed for the task
with the worst-case response time. This task will then be guaranteed a
response within the total of these execution times if that total is no
greater than the inter-arrival time :math:`T_{i}`.

.. math::

    R_{i} =
        B_{i} +
        \sum_{j \, \in \, \mathbf{H}_{i}}
            C_{j} \left \lceil \frac{T_{i}}{T_{j}} \right \rceil

If the actual worst-case response time is even smaller than this
estimate, we can determine a smaller overestimate. For each task at an
equal or higher priority to :math:`\tau_{i}`, we consider each multiple
of its minimum inter-arival time that is no greater than the
inter-arrival time of :math:`\tau_{i}`, each of these being a member of
:math:`\mathbf{S}_{i}`.

For each such duration, we
consider the total of the worst-case blocking time :math:`B_{i}` and the
total execution of all equal or higher priority jobs that can be
released in that duration.
.

.. math::

    \mathbf{S}_{i} =
        \left \lbrace
            kT_{u} \;
            \middle | \;
                u \in \mathbf{H}_{i} \, ,
                k \in
                    1 \, .. \left \lfloor
                        \frac{T_{i}}{T_{u}}
                        \right \rfloor
        \right \rbrace

For each duration in :math:`\mathbf{S}_{i}`, we consider the total of
the blocking time :math:`B_{i}` and, for each task at an equal or higher
priority than :math:`\tau_{I}`, that task's worst-case execution time
multiplied by the number of releases of that task that may occur in
the duration from :math:`\mathbf{S}_{i}`.

.. math::

    R_{i} =
        \underset{s \, \in \, \mathbf{S}_{i}}{\min}
        \left (
            B_{i} +
            \sum_{j \, \in \, \mathbf{H}_{i}}
                C_{j} \left \lceil \frac{s}{T_{j}} \right \rceil
        \right )

The worst-case response time is the smallest of these total execution
times and task is schedulable, if that time is no greater than the
duration for which it is considered. i.e., :math:`\tau_{i}` is
schedulable within the given task set if the following is true:

.. math::

    \exists s
        \land s \in \mathbf{S}_{i}
        \land
            \left (
                B_{i} +
                \sum_{j \, \in \, \mathbf{H}_{i}}
                    C_{j} \left \lceil \frac{s}{T_{j}} \right \rceil
            \right )
            \le s

.. figure:: ./image/response-time.eps
    :height: 6cm

    :label:`fig:response-time` Response time analysis for a single task
    within a simple set of tasks

    This shows un upper bound on the response time of :math:`\tau_3`
    when scheduled in a system with :math:`\tau_1` and :math:`\tau_2` at
    a lower priority than both. The darkened durations to the left
    indicate the worst-case blocking time for each job of that task.
    The bar along the bottom shows the total of the blocking time for a
    job in :math:`\tau_3` and the worst case execution time as jobs are
    released from all tasks after the release of a job in
    :math:`\tau_3`. The coloured dotted lines compare the multiples of
    the minimum inter-arrivals of each task with the total worst-case
    execution for the jobs released within that time. The blue dotted
    line indicates the smallest multiple of a task's inter-arrival time
    that is no less than the total of the worst-case execution times of
    jobs released, and thus, a bound on the response time of
    :math:`\tau_3`.

For each such period we can also determine a slack time, :math:`X_{s}`,
which is the amount of execution time available after completion of all
tasks at a priority equal to or greater than :math:`\tau_{i}` in the
period :math:`s`. The slack time of :math:`\tau_{i}` is then the
greatest such :math:`X_{s}`.

.. math::

    s \in \mathbf{S}_{i} \Longrightarrow X_{s} =
            s - \left (
                B_{i} +
                \sum_{j \, \in \, \mathbf{H}_{i}}
                    C_{j} \left \lceil \frac{s}{T_{j}} \right \rceil
            \right )


.. figure:: ./image/slack-time.eps
    :height: 6cm

    Slack time for a single task within a simple set of tasks

    This shows the *slack time* for :math:`\tau_3` when scheduled as in
    :ref:`fig:response-time`. The sum of the blocking time and all jobs
    released is extended up to the minimum inter-arrival time of
    :math:`\tau_3`, with lines relating the multiples of inter-arrival
    times of each task to the sum of the total of the blocking time for
    :math:`\tau_3` and the WCET of all tasks released. The green dotted
    line shows the multiple of an inter-arrival time with the greatest
    value when the total of the blocking time and WCET of released jobs
    is subtracted, and this, the slack time for :math:`\tau_3`.

From this, we can also produce a critical scaling factor,
:math:`\Delta^{*}`, which is the greatest factor by which total system
execution can scale before becoming unschedulable. A critical scaling
factor of less than 1 implies an unschedulable system as well as the
factor by which execution time must be scaled to achieve schedulability.

.. math::

    \Delta^{*} =
        \underset{i \, \in \, 1 .. n}{\min}
        \left (
        \underset{s \, \in \, \mathbf{S}_{i}}{\max}
        \; \frac{s}{s - X_{s}}
        \right )

We can also observe that if we substitute a task :math:`\tau_{j}` with
an arbitrary set of tasks :math:`\mathbf{U}_{j}` that have the same
priority and minimum inter-arrival time as :math:`\tau_{j}` and that
have a combined worst-case execution time equal to that of
:math:`\tau_{j}`, then the interference on lower-priority tasks is
unchanged.

.. math::

    \forall t.
        \sum_{v \, \in \, \mathbf{U}_{j}}{C_{v}} = C_{j} \Longrightarrow
        \left (
            \forall v \in \mathbf{U}_{j} \Longrightarrow
                T_{v} = T_{j}
        \right ) \Longrightarrow
        C_{j} \left \lceil \frac{t}{T_{j}} \right \rceil =
            \sum_{v \, \in \, \mathbf{U}_{j}}{
                C_{v} \left \lceil \frac{t}{T_{v}} \right \rceil
            }

As sporadic servers :cite:`Sprunt_SL_89` model a sporadic tasks as an
infinite number of tasks with an equal minimum inter-arrival time and
priority and a known total worst-case execution time, they can be
considered in this scheduling analysis as the equivalent aperiodic task.

This model only captures execution time consumed in two manners: when a
task at a fixed priority executes, and when a task at some priority
level is preempted due to execution not attributed to a higher priority
task. This model also assumes that budget for job is lost when that job
completes. For an enforcing scheduler to both satisfy these
requirements, it must ensure:

 * that the actual execution time of every task is divided into jobs,
 * that each job of a task not be allowed to execute for more than the
   assumed worst-case execution time,
 * that any consecutive jobs of a task are never permitted to execute
   with less than the minimum inter-arrival time of their task
   separating their releases, and
 * that all execution time that preempts a task is either attributed
   to a task with a fixed higher priority or being bounded by the
   assumed blocking time.

If we apply these requirements for a scheduler of tasks with a
*deadline-monotonic* (DM) or *rate-monotonic* (RM) fixed priority
assignment with resources accessed using the *immediate priority ceiling
protocol* (IPCP), we find that any execution time that that preempts a
task that is not attributed to higher-priority task must be bounded by
the blocking time of of that task. We also find that all resource
accesses from lower-priority tasks to resources higher priorities must
be additionally considered in this bound; no task should be able to
access a resource for longer than the blocking time of each task at a
lower priority than that resource. Additionally, we must guarantee that
a task does not change its priority relative to other tasks by any means
other than a resource access within these bounds. In a system where
tasks may suspend or block, all available execution time must be either
forfeited or the task must consume time as though it were executing for
each duration for which it was blocked or suspended.

If we can guarantee these bounds in the seL4 kernel, then the ability
for any task to meet any deadline depends only on its own correctness,
the correctness of any shared resource implementation, that the WCET
enforced by the kernel is no less than its actual WCET of the task, and
that the kernel enforced priority inversion bound at any priority level
is no less than the WCET of any shared resource access that occurs at
that priority.  This ensures that the correctness of any task does not
depend on the correctness of any other task when no dependency
relationship exists.

Whilst the constraints regarding scheduling algorithm and resource
sharing protocol here do simplify the means by which we perform the
check, the general approach can be applied to a wider range of
scheduling configurations without significant change to the properties
that must be enforced by the kernel or the trust relationship between
tasks. This is what will ensure that we can provide the robust
scheduling guarantees necessary for mixed-criticality systems.

For seL4 to guarantee the assumptions of fixed-priority scheduling
analysis such as RTA (:ref:`response-time-analysis`), it must allow for
the modelling of tasks with fixed priorities, enforce a maximum bound on
the time for which any task may execute at a raised priority level, and
enforce a known bound per job on preemption from sources other than
resource accesses and higher priority tasks. If such a system is to be
configured by user-level components, any component with the ability to
configure the scheduling configuration of a task, including its
priority, worst-case execution time, and inter-arrival time, or the
scheduling configuration of a resource, including its priority and the
bound on the execution time of each access, must be verified to conform
to the configuration assumed by any timing analysis.

.. Make sure to explicitly refer to temporal isolation

.. takeaway paragraph - response time analysis

seL4
====

:citet:`Klein_AEHCDEEKNSTW_10` presents seL4, a formally verified
microkernel that has been proven to provide guaranteed integrity,
availability, and isolation between software components in correctly
configured systems :cite:`Murray_MBGBSLGK_13`. seL4 uses capabilities to
model and control access to all resources of a system, both those
provided by the kernel implementation itself and those managed by
user-level components. The seL4 kernel directly manages access to
physical memory, virtual to physical address translation configuration,
capabilities themselves, and generic communication channels.

Certain capabilities may represent access to specific resources, such as
a particular region of physical memory or the physical address space,
with some constrained set of rights to act on that resource. For a
thread to act on any such resource, it must have direct access to a
capability to said resource with the rights sufficient for the desired
action.

Some capabilities represent communication channels that are mediated by
the kernel and that may alter the scheduling state of the communicating
threads such as to block and unblock threads when a communication
occurs. Synchronous communication channels can be used to send
capabilities as well as data between threads.

.. What are the characteristics of seL4?

.. How does seL4 compare to other microkernels?

.. In-kernel scheduler

.. Formally verified

Mixed-criticality scheduling
----------------------------

:citet:`Lyons:phd` introduces a set of extensions to the seL4
microkernel referred to as the *mixed-criticality scheduling* (MCS)
extensions. Prior to these extensions, the scheduler provided within
seL4 allowed for round-robin scheduling over a set of threads with fixed
priorities. A queue of threads was managed for each fixed priority
level, with the thread from the head of the highest-priority non-empty
queue being selected for execution. After a number of kernel ticks, 5 by
default with each tick being 2ms apart, the currently executing thread
would be placed on the end of the queue of its priority and the new head
would then be chosen for execution. This implementation also allowed a
simple form of *timeslice donation* to occur, whereby a communication to
a blocked thread at new highest priority would allow that thread to
consume the remaining time before the next kernel tick.

Whilst this scheduling policy is sufficient for many non-realtime
systems, it is not sufficient for realtime systems, as it does not
satisfy any of the guarantees mentioned in
:chapterref:`response-time-analysis`. A user-level scheduler can be
implemented on top of this scheduler, although the amount of overhead
introduced by performing scheduling operations at user-level is
undesirable.

The MCS extensions introduce new resource capability, a *scheduling
context* (SC) that models execution time made available on a specific
core of a system. It also introduces a *scheduling control* capability
that is required to allocate time on a particular core to a scheduling
context. A scheduling context is configured with a number of refills, a
budget, and a period. A scheduling context can be donated from one task
to another via synchronous IPC, emulating the behavior of thread
migration. This can also be used to model a resource server by
constructing a thread that waits on an IPC object without a configured
SC and that is donated the SC of any client such that it executes using
the client's SC until it responds.

The MCS extensions do not alter the manner in which a thread's priority
is configured. A capability to a pair of *thread control blocks* (TCB)
is all that is required to alter priority of one of those threads. Of
the pair, one provides a *maximum configured priority* (MCP), which
enforces an upper bound on the new priority and MCP assigned to the
other thread.

.. A SC with :math:`n` refills, a period of :math:`p`
    and a budget of :math:`b` can be considered as a set of :math:`n-1`
    tasks, all with a minimum inter-arrival time of :math:`p` and with a
    combined worst-case execution time of :math:`b`. 

The scheduler enforces a sliding window constraint on the execution
associated with each scheduling context. In any period of time equal to
the scheduling context's configured period, no more than the scheduling
context's budget may be consumed by a thread executing using the time of
the scheduling context. This places a fixed *bandwidth* of time
attributed to any SC, irrespective of the priority at which the time of
the SC is consumed and any blocking behaviour that the thread associated
with the SC may exhibit. The number of refills assigned to a task bounds
the degree to which the execution time associated with a SC can be
fragmented, with bandwidth being lost whenever a preemption or blocking
operation would fragment the execution into a number of distinct
durations per period that is greater than the number of refills.

Whilst this model provides a number of useful mechanisms for dealing
with time as an explicit resource, the guarantees provided by the
scheduler under this implementation do not relate in any useful way to
the scheduling assumptions of our timing analysis. Whilst the bounds
enforced are no greater than the bounds on execution assumed by the
real-time analysis, they do not provide any guarantee that sufficient
execution time would be provided for a given task to execute to up to
its worst-case execution time within the provided budget as execution
budget is reduced whenever a task is not executing, even if only due to
preemption. This model also fails to enforce sufficient bounds on
execution for accesses to resource servers, as the scheduling context
donation effectively allows a task to permanently change its priority to
that of the resource server. Any task with access to a TCB capability is
able to modify the priority of that TCB, although this could be
configured in a manner such that components other than any trusted
schedulers can only reduce the priority of those tasks. Any task with
access to multiple TCBs and multiple SCs is also able to swap the
priorities at which any of those SCs expend budget.

In addition to the issues present in the model provided by the MCS
extensions, there are a number of issues present in the implementation
itself, particularly with regards to preemption from the kernel, both
for external interrupts and for the purposes of context switching. Each
kernel entry will include a read of the scheduler timer, with all time
prior to the timestamp being attributed to whichever SC was active at
the point the kernel entry began and all time after the timestamp
attributed to the SC that was active at the point where the kernel entry
completed. When a kernel entry occurs due to an external interrupt, this
time is attributed to the executing SC even if it is unrelated to the
execution of the executing task. When a kernel entry occurs as part of a
preemption to begin a higher priority task, part of that kernel
execution will be charged to the lower-priority task, despite being for
the purposes of the higher priority task.

Finally, the scheduler will preempt the currently running task each time
a job of a task is released asynchronously, even if that task is at a
lower priority than that of the task executing at the time. While this
does incur a cost to the executing task, the number of lower priority
releases is per job is bounded by the number of lower priority tasks. As
the cost is bounded, it can be considered as part of the worst case
execution, although it would be more accurately tracked as component of
the blocking time for that task.

In order to ensure that the assumptions of scheduling analysis are
guaranteed by the kernel scheduler, substantial changes are required of
the scheduling model provided by the kernel. Preemptive kernel execution
must be clearly attributed and bound by some explicit task that is
responsible for the preemption, or bound and attributed to the blocking
time assumed for each task. Priority increases, such as resource
accesses, should be modelled such that the both appear as normal task
execution to tasks with a lower priority than any client and must be
bounded by the blocking time of any tasks at a higher priority than any
client.

.. What are the characteristics of the MCS scheduler?

.. How does the model of MCS relate to scheduling algorithms and
   analysis?

.. Bounds execution of tasks

.. sliding window

.. takeaway paragraph - seL4

Approach
========

.. This section is about the model we are going to use to resolve these
   issues

.. How do we model real time tasks on seL4? SCs

To produce a real-time scheduler that correctly guarantees the
assumptions of our timing analysis, we will model our system of tasks
and resources using seL4 primitives, modifying the implementation as
needed. The modifications should avoid introducing unnecessary overheads
on other uses of the kernel such that we could not introduce them into
the distributed seL4 implementation. As we are only seeking to model a
deadline-monotonic (DM) schedule with the immediate priority-ceiling
protocol (IPCP) for shared resource access, the system can be modelled
directly on the existing primitives introduced with the
mixed-criticality scheduling (MCS) extensions.

Modelling tasks with scheduling contexts
----------------------------------------

As our timing analysis only models aperiodic tasks with jobs that cannot
self-suspend in any way, we must constrain execution of all tasks in the
system to be either running jobs or completed jobs of aperiodic tasks.
For each task we must ensure that the jobs never execute for more than
the assumed worst-case execution time and that no two consecutive job
releases of a task are less than the task's minimum inter-arrival time
apart.

seL4 provides mechanisms to directly suspend and resume threads and
allows threads to suspend for the purposes of inter-process
communication (IPC). We must ensure that the effects of these operations
don't break the assumptions of the timing analysis, either by ensuring
that a blocked thread with an SC is scheduled and charged time as though
it was running for the duration it was blocked or suspended, or by
scheduling SCs as though they have no released jobs when they become
blocked.

As the intent of the blocking mechanisms in the kernel is intended to
allow lower-priority tasks to execute when higher-priority tasks are
waiting for some external event or a signal from another task, choosing
to model the SCs associated with suspended threads as having no released
jobs makes the most sense. If a thread must wait in a way that does not
complete a job, a user-level spinlock would be the most appropriate
mechanism to remain compatible with timing analysis.

With this approach, we have two conditions for a job of an aperiodic
task to be released: the minimum inter-arrival time since the last job
of that task was released was passed and the task is associated with a
thread that is not blocked. We also have three conditions that can lead
to an aperiodic job being completed: the task executes for its
worst-case execution time, the task forfeits any remaining execution
time, or the thread associated with the task suspends or blocks.

We only ever need to model a single job of any aperiodic task. When that
task completes, we configure a release of the next job in the future
no earlier than the task's minimum inter-arrival time after the release
of the completed job. If we reach the point in time of the subsequent
release and the associated thread isn't blocked, the job is released. If
the associated thread is unblocked or resumed and it is after the time
of the subsequent release, the job is released at the instant it becomes
unblocked.

As each SC models a set of aperiodic tasks with a combined worst-case
execution, we track the total of the worst-case execution of the tasks
that are more than the minimum inter-arrival time since their last
release, the *total available budget* of the SC. We also track the
individual worst-case times of the unreleased tasks in the set and the
point in time at which they would next release using the replenishments
of the SC. For periodic and aperiodic tasks modelled with a dedicated
SC, this requires only a single replenishment in addition to the record
of total available budget.

Not all tasks that we wish to include in a system may necessarily behave
as a single aperiodic task. For tasks which may have more *sporadic*
activations, we can instead use the sporadic server (SS) model
:cite:`Sprunt_SL_89` which models sporadic tasks as an infinite set of
aperiodic tasks with equal priority and minimum inter-arrival time and a
bounded total worst-case execution. To model this in seL4, a scheduling
context (SC) will be used to model an infinite set of aperiodic tasks,
each with the same priority and minimum inter-arrival time and with a
bounded total worst-case execution time.

A sporadic task can also be modelled with a dedicated scheduling context
with the total worst-case execution time of all released tasked tracked
in the total available budget and each replenishment recording an
instant where an infinite set of aperiodic tasks would be released and
the total worst-case execution of those tasks. As the number of
replenishments that can be tracked for an SC is bounded, when a set of
aperiodic tasks completes and the maximum number of replenishments are
already in use, the last replenishment is delayed to the time when the
new replenishment would need to be created. As can be seen by this
model, the actual number of replenishments does not bound the *number*
of aperiodic tasks modelled by the single sporadic tasks, only the
number of grouped releases of infinite subsets of those aperiodic tasks.

Removing the sliding window constraint
--------------------------------------

seL4 enforces a sliding-window constraint on the execution of all tasks,
preventing a task from executing when its continued execution would
the violate the constraint. The constraint requires that for any window
of time equal to the SC's configured period, no more than the SC's
configured budget in execution may be charged to that SC. A well behaved
real-time task may be expected to expend as much as twice its configured
budget in any window of size equal to its period in a fully schedulable
system. This can occur if its worst-case response time is equal to its
inter-arrival time when one job observes the worst-case response time
and is followed immediately by a job that is not preempted.

When this constraint is applied to tasks where the budget is configured
to the task's WCET and with period configured to match the minimum
inter-arrival time of the task, any interference to a task's execution
from higher-priority tasks introduces delays to the task's future
release times, leading to inevitable deadline misses. This generally
leads to all but the highest priority tasks missing deadlines almost
shortly after the system has started.

.. figure:: ./image/sliding-window.eps
   :height: 6cm

   Three periodic tasks with the sliding window constraint applied

   The task set contains:

    * a high priority task with a WCET of 1 unit and a minimum
      inter-arrival time of 5 units,
    * a medium priority task with a WCET of 3 units and a minumum inter
      arrial time of 7 units, and
    * a low-priority task with a WCET of 2 units an a minimum
      inter-arrival time of 11 units.

   With the sliding window constraint applied to each of these tasks,
   when a unit of time is consumed a release of that unit of time is
   placed in the future by the minimum inter-arrival time. Whevever a
   job of task is preempted, not only is the response time of the
   preempted job increased, but the response time of all subsequent jobs
   of that task is also increased. This produces an unbounded worst-case
   response time for all but the task with the highest priority.
   Response time analysis gives a worst-case response time of 5 units
   for the medium priority task and 7 units of time for the second
   case. The second job of the medium-priority task can exceed its
   assumed worst-case response time by its fourth job and the
   low-priority task can exceed its worst-case response time by its
   second job.

The current implementation tracks a set of replenishments for each task.
A task stops consuming budget when it stops executing for any reason,
such as due to preemption from another task, explicitly suspending, or
by blocking to wait for an external event or IPC from another task. At
this point, the execution time consumed while the task was running is
scheduled as a release one period after the task last began execution.
Any available budget left unused can be consumed when the task next
runs. When a task exhausts all available budget, it is forcefully
stopped and either faults or cannot execute again until it reaches the
point of a future replenishment. If a task is stopped, preempted, or
calls into the kernel when the maximum number of future replenishments
are configured, the task loses all available time until the next
replenishment becomes available. A task may also voluntarily forfeit any
available budget.

To resolve this, we change the constraint on SCs to be that of the
sporadic server algorithm :cite:`Sprunt_SL_89`, which models each task
as an infinite set of aperiodic tasks with the same priority and period
and with a bounded total budget. As we cannot model each task of an
infinite set individually, we instead only track the total WCET of
subsets of tasks that are released at the same time and bound the number
of these groups that we track. Where we would need to record the release
of a new subset but have reached the bound on the number of subsets we
can track, we take the latest tracked subset and delay it to be released
at the same time as the new subset to be scheduled. As such, this
produces a reduced bandwidth for any sporadic tasks when it attempts to
execute across more subsets than there are refills in an SC.

.. What is the particular issue?

.. What is the effect of the particular issue in terms of the analysis?

.. What is the proposed solution?

.. Use a version of seL4 with a relaxed bound of sporadic server rather
   than sliding window

Correct attribution of execution time
-------------------------------------

As we intend to enforce execution time by charging scheduling contexts
(SCs) for time spent executing, we must take care to ensure that each SC
is only charged for the execution time that our timing analysis has
assumed is associated with the task that the SC represents. For each
task, we attribute all user-level execution while that task is running
to that task. We also attribute the cost of all explicit kernel entries,
i.e. system calls, made while that task is running to that task. We can
also attribute kernel entries due to user-level exceptions, such as
arithmetic exceptions or invalid memory accesses, to the SC as they
should be triggered by the execution of user-level code.

This leaves two cases where the task that must be charged for execution
is less clear: when the kernel is entered due to a task with no released
jobs receiving a job release, and when an external interrupt triggers a
kernel entry.

Ideally, the kernel would only enter for the release of a job of a task
of a strictly higher priority. The current implementation of timed
releases in the seL4 kernel uses a single queue sorted by release time,
requiring a kernel entry whenever the head element of the queue would
observe a release, even if it is at a lower priority. This is required
as a higher-priority task may appear later in the queue. An alternative
could be to find the first element in this queue with a higher priority
and configure the timeout for that point in time, or to maintain a
separate release queue for each priority level. Both cases could
increase some scheduling operation in a potentially unbounded manner.

The contribution of releases of lower-priority tasks to the WCET of any
given task can be considered as bounded. The number of these
releases is bounded by the total number of lower-priority tasks and the
cost of each release is reasonably bounded by some WCET to enter the
kernel and remove an element from the release queue. Each task in the
system must include the cost of all such lower and equal-priority
releases in that task's WCET.

If a release of a job from a higher-priority task occurs, this will also result in
a switch to that higher-priority task. We can attribute the entire cost
of the kernel entry for that release to the released task and account
for it once in each job of that task. This is preferable to attributing
that cost to the task that was running at the time the release occurred
as this can occur as many times as higher priority jobs can be released.
Where higher priority tasks are only periodic or aperiodic, this is
strictly bounded by the minimum inter-arrival time. In the presence
higher-priority sporadic tasks, however, a task may see an effectively
unbounded number of higher-priority releases. If this cost were to be
considered part of the preempted task's execution, the assumed cost
would be unbounded.

Attributing kernel time to external interrupts is more difficult,
particularly given the implementation of interrupts within seL4. seL4
divides interrupts into 4 general types:

 * the timer interrupt, for triggering events in the in-kernel
   scheduler;
 * signals, which produce a signal to an IPC object that can be received
   by a user-level thread;
 * inter-processor interrupts (IPIs) for asynchronous signalling in the
   kernel between cores; and
 * reserved interrupts, for internal kernel mechanisms.

As the timer interrupt is only used for the timer itself, indicating
either that the current task has exhausted its budget or that a job for
another task has been released, kernel entries for this interrupt have
already been correctly attributed.

If a signal interrupt occurs, it would be ideal if the cost of that
interrupt were charged to the task that receives the interrupt. If we
only allow an interrupt to be received when a task is waiting, and
associate that waiting task directly with the interrupt, then that time
could be charged to the task. The kernel implementation currently
separates the association between an interrupt and the IPC object that
it signals from the association between the IPC object and any thread
blocked waiting for receive. This makes it difficult to robustly ensure
that an IRQ is only unmasked when a thread is blocked waiting for a
signal on an IPC object associated with the IRQ.  Another complication
with this approach is that it can cause interrupt events to be
unexpectedly missed.

.. figure:: ./image/irq-execution.eps
   :height: 6cm

   Execution trace of a task set including IRQ handlers and a periodic
   task

   This task set contains a high-priority aperiodic task handling IRQs,
   a medium-priority periodic task, and a low-priority aperiodic task
   handling IRQs of a different device. Dotted arrows indicate a timer
   IRQ marking the minimum inter-arrival time after the previous release
   of a task. Dashed arrows indicate an external device IRQ handled by a
   specific task. Dark regions of an execution trace indicate preemptive
   execution in the kernel, either to switch between tasks or to handle
   an IRQ.

The approach we use here instead treats all signal IRQs as explicit
tasks. Absent any ability to assign priorities to IRQs, we instead treat
all IRQ tasks as having an equal priority above all non-IRQ tasks. Each
IRQ is assigned a SC such that it is only unmasked when it has available
budget and is charged the cost of any kernel entry where the IRQ is
delivered. This also provides a convenient mechanism for bounding the
rate at which certain interrupts are delivered. This approach could be
further extended by allowing IRQs to be assigned specific priorities
such that they are also masked while higher priority tasks are
executing. This would also allow IRQs to have independent bounds on
minimum inter-arrival time in rate monotonic and deadline monotonic
schedules.  This approach is not considered in depth here as it goes
beyond what is strictly required to ensure that the execution time
associated with kernel interrupt handling is attributed correctly.

We do not consider multicore systems in any depth in this thesis, so we
assume IPIs do not occur. In a multicore system, they would be used to
trigger kernel operations across cores for synchronising state and
communicating between threads. If a real-time system isolated to a
single core of an seL4 system does not receive changes to its scheduling
state, changes it its virtual addressing, or communications from other
cores via the kernel, then these IPIs are avoided. This would not,
however, exclude communication to other cores via shared memory or
signalling external cores from the real-time core.

Reserved IRQs are architecture-dependant and are handled by the kernel
itself. IRQs that indicate a user-level exception within the
architecture's virtualisation mechanisms can be treated the same as any
other user-level exception, with the associated kernel entry time
attributed to the running task. IRQs associated with external devices
managed in the kernel, such as the IRQs associated with managing device
MMU faults, are more complex to correctly attribute time to and left out
of the scope of this thesis.

The current implementation of kernel time only splits time once for each
kernel entry, soon after the most recent point where an external
interrupt could be received. All time before this is attributed to the
task that was running when the kernel entry began and all time after is
charged to the task that is running when the kernel then exits. This
approach makes it difficult to account for the cost of kernel entries in
any of the timing analysis, as it doesn't strictly associate the kernel
costs with any particular task.

.. figure:: image/seL4-charge.eps

    Time charged to tasks for all kernel entries

    When a kernel entry occurs, part of each entry is charged to the
    task that was active when the kernel entry began and part is charged
    to the task that was active when the kernel entry completed.

To implement the more accurate assignment, we only need to split time at
each kernel entry and exit. The time between entry and exit is charged
to either an interrupt task, the task that was running when the kernel
entered, or the task that was running when the kernel exited. We can
also use an overestimate of this kernel entry duration as long as it is
smaller than some known worst-case bound.

.. figure:: ./image/sched-timing.eps

    The timing points related to the kernel entry and exit time

    The kernel attempts to overstimate its entry time,
    :math:`\mathbf{b}`, by reading the timestamp soon after entering the
    kernel at :math:`\mathbf{c}` and subtracting a worst-case entry time
    to produce an estimate, :math:`\mathbf{a}`, that is no later than
    the actual entry.
    The kernel also attempts to overstimate its exit time,
    :math:`\mathbf{e}`, by reading the timestamp soon before exiting the
    kernel at :math:`\mathbf{d}` and adding a worst-case exit time to
    produce an estimate, :math:`\mathbf{f}`, that is no earlier than the
    actual exit.

.. figure:: image/syscall-charge.eps

    Time charged to tasks for a system call or user-level exception

    When a task calls into the kernel or produces a user-level
    exception, the resulting kernel entry is charged to the task that
    was current at the point where the kernel entry began.

.. figure:: image/preempt-charge.eps

    Time charged to tasks for a preemptive task switch

    When the timer causes a higher priority task to begin execution, the
    kernel time is charged to the task that was current at the point
    where the kernel entry completed.

.. figure:: image/irq-charge.eps

    Time charged to tasks for an IRQ with no switch

    When the kernel enters due to an IRQ handled at user-level, the
    kernel time is charged to the SC associated with the IRQ.

The changes to the implementation to track the kernel implementation
itself should be minimal, only requiring a read of the current time
either at the point the kernel is entered or the earliest point after a
interrupt can be received and then immediately before a return to
user-level, with an over-assumption kernel entry and exit time added.
The changes to bind scheduling contexts directly to interrupts is also
likely to be straightforward, only requiring SCs to track when they are
associated with an IRQ and for the kernel to maintain a table of SC
capabilities associated with the IRQs.

.. -----

    of that task is we can also assume that any
    explicit kernel entry in the code executed for a task is considered part
    of that task's execution. The kernel entry resulting from an exception
    that is the direct result of the implementation of a task, such as an
    arithmetic exception or an invalid memory access, can also be attributed
    to that task's execution.

     For each job of each
    task, we can easily assume a worst-case cost for the release of that
    task and for the completion of that task,

    This leaves two cases where a

    We will modify the seL4 kernel to enforce the bounds on execution time
    assumed by the response time analysis for each task in a real-time task
    set. Doing so will bound the interference time for every job in every
    real-time task. The implementation of any task within a task set is
    required to ensure its own correctness and its ability to execute to
    completion for each job within the bounds enforced by the kernel.

    The possible sources of execution that can interfere with a task in a
    seL4 system are all associated with another released task's execution or
    an entry into the kernel. Any execution time expended by an equal or
    higher-priority task is simply is simply charged to that task. Any time
    expended by a lower-priority task accessing a shared resource must be
    bounded by the configuration of that shared resource such that no access
    to that resource may exceed some known time bound.

    To bound interference from execution of the kernel itself, we must
    attribute all kernel execution time to some task in the system with
    sufficient execution budget to perform the task. The kernel can be
    entered either as an explicit call by the task, as the result of a fault
    in the executing task, or as an interrupt from an external device or
    processing core. Of these, the first two are the result of the
    implementation and correctness of the task itself and so any associated
    execution is attributed to the executing task until some other task
    begins execution. When the kernel is entered due to an external
    interrupt, the time must be associated with some task that bounds the
    delivery of the interrupt such that the interrupt delivery can be
    considered for analysis.

    A kernel interrupt due to the kernel's timer device may indicate the
    release of the job of another task in the system. If that job is at a
    higher priority, that task will continue execution in place of the
    current task and can be charged the entire execution time of the kernel
    consumed to perform the switch. If the job is at a lower or equal
    priority, that time is bounded as it may only occur once in the duration
    of any task per task of equal or lower priority. This time is charged to
    the currently executing thread as a limited form of bandwidth donation
    as charging that time to the task of the released job would lead to a
    further postponement. Ideally, only higher priority tasks would be able
    to preempt an executing task in this manner avoiding this cost entirely,
    however the changes required to achieve this are beyond the scope of
    this project.

    The timer interrupt may also indicate that the executing task's
    available budget has been completely exhausted. These interrupts should
    be scheduled such that the time needed to switch away from the task can
    be completely charged to the executing task with minimal overrun. In
    seL4 systems with multiple scheduling domains, the timer may also
    indicate the end of a scheduling domain, however the use of the
    hierarchical domain scheduler is not considered in this work.

    A kernel interrupt from an external core is usually the result of
    another core reconfiguring the scheduler of the interrupted core, either
    due to the reconfiguration of a SC or thread in the interrupted core's
    scheduler, or due to a communication with a thread in the interrupted
    core's scheduler that should now preempt the executing thread on the
    interrupted core. The first of these cases is out of scope for the
    current project as we do not consider dynamically configured realtime
    systems. Cross-core resource sharing and synchronous communication are
    also not considered as the existing mechanisms are insufficient to
    ensure that blocking and interference on resource access across cores is
    bounded sufficiently for any form of analysis. Cross core asynchronous
    communication should only require an interrupt on a core when the
    recipient of a notification would preempt the task already executing on
    that core and so the entire cost of the switch would need to be charged
    to the task receiving the communication. Managing time for any
    cross-core interrupts that are not to preempt the executing task, such
    as those for invalidating translation tables and migrating cached FPU
    state are out also of scope.

    A kernel interrupt from any other external device must be attributed to
    some task with available budget such that any time expended to enter
    into the kernel and to signal the arrival of the IRQ to user-level can
    be bounded and considered for analysis. Where no such task is available
    to be charged for the time, the IRQ must be masked such that it could
    not be delivered to produce a kernel entry.

.. Bounding priority inversion?

    With the above constraints, all execution time is attributed to some
    task. Each task assumes some worst-case switch time for each job
    released and when each job completes. Any execution interference for a
    job is charged to other tasks and is bounded by the total execution of
    higher-priority jobs and the execution bound of the shared resource with
    the greatest bounded execution time that has an equal or higher
    priority. For a highly critical task with hard deadlines, we then need
    to ensure that execution time of the job itself does not exceed assumed
    WCET and that the execution time of any shared resources that it
    accesses would not exceed the configured execution time bound.

.. Make sure to use diagrams here

.. What are specifically trying to resolve?

.. Bound all sources of 'external' execution

.. How have we constrained the scope of the problem?

.. Specifically address the following class of configurations:

   - Deadline (or rate) monotonic fixed priority
   - Single core
   - Priority ceiling protocol

.. How does the problem manifest it within the scope?

.. How will we address each issue?

..
    Precisely attributing execution time
    ------------------------------------

.. Active voice: "the scheduler charges" rather than "is charged"

..
    The existing implementation of the seL4 kernel records the current
    time after entering into the kernel and before performing any work in the
    kernel. It also records the current time at any point where the kernel
    may be preempted in long-running operations. Any time before to the
    timestamp is always charged to the task that was current upon kernel
    entry and time consumed after the timestamp is charged to the task that
    is current when the kernel returns execution to user-level. This leads
    to the currently executing task being charged some amount of time
    whenever a kernel entry occurs, including for entries related to
    preemption and interrupt delivery. In the presence of sporadic tasks, it
    is almost impossible to bound the number of these preemptions for any
    for of analysis so instead we seek to charge kernel execution time more
    precisely, ensuring it is entirely charged to the task responsible for
    the entry. In the case of preemption, time must be charged to the task
    that began execution with the kernel entry. For interrupt delivery, the
    time must be charged to the interrupt task. Only for system calls and
    user-level faults that lead to entries into the kernel should the time
    must be charged to the executing task.

.. In order to charge the kernel execution time correctly, we need an
   underestimate for the time at which execution switches from
   user-level into the kernel and an overestimate for the time at which
   execution returnes to user-level. When the execution cost will be
   charged to the task that is executing after the kernel entry, only
   the entry estimate time is required as all time after the return to
   user level will be charged to the same task as the time consumed by
   the kernel. In any case where the kernel entry is due to the
   completion of a job, only the exit estimate time is required as all
   time before the kernel entry will be charged to the same task as the
   kernel execution time. In the case where the kernel entry is due to a
   interrupt delivery that does not result in a pre-emption, both
   estimates are required as the time is charged to a task that is
   neither that of the task at entry or exit unless the preemption is a
   release of a task at an equal or lower priority task.

.. To underestimate the entry time, we record the time as early as possible
   on all kernel entries and preemption points and subtract an
   overestimate of the worst case kernel entry time and timer latency.
   Determining an overestimate for the time at which user-level
   execution resumes is more difficult. The exit time estimate needs to
   be known at the point where the cost of kernel execution time would
   be charged which requires the duration of kernel execution after that
   point in time to be bounded and preferably consistent.

.. For the case where the kernel time is charged to a task that has
   completed, this time needs to be known near the end of the kernel
   execution just as the kernel switches the current SC, with the code
   paths beyond this point varying minimally. For this case, getting the
   timestamp at this point and adding a worst-case exit cost would be
   sufficient with the exit cost being fairly consistent.

.. For the case where the kernel time is charged to an SC associated with
   the delivery of an IRQ, the exit time depends on several other
   conditions and may occur in conjunction with other cases, such as the
   current task completing execution or the release of a higher-priority
   task resulting in a preemption. We do, however, also know that there
   will only be one IRQ after a successful entry into the kernel
   (although any number of inter-processor interrupts (IPIs) may need to
   be handled in that time).  As such, in the case of an IRQ, we record
   the SC to be charged for an interrupt and when we reach the point at
   which SCs would be switched, if there is an interrupt SC set, we
   charge the kernel execution time since the last timestamp update to
   that SC.

.. attempt 2

    To precisely account execution time and attribute execution time to the
    appropriate tasks, i.e., the task for the task to which the time demand
    analysis assumes each portion of time would be charged, we must make
    some overestimate for the execution time of each continuous and
    non-preemptable duration of kernel execution. This requires some
    estimate that is no later than the start of each duration and some
    estimate that is no earlier than the end time of each duration. In some
    cases these durations may be consecutive such that the instant that one
    duration ends is the instant that another starts, in which case the
    instant determined must be such that both durations are within the
    assumed execution time for the task to which they are attributed.

    There are two points at which kernel entries that must be distinctly
    attributed may occur: the handling of *inter-processor interrupts*
    (IPIs) whilst waiting on a kernel lock and the points in long-running
    system calls. The other points at which a duration of kernel execution
    may begin are entries into the kernel for user-level faults, system
    calls, and the delivery of interrupts such as the timer interrupt for
    the kernel scheduler, an IPI, or an IRQ handled at user-level. Kernel
    execution eventually ends with a return to user-level or to a low-power
    idle thread which may or may not be the same thread as was running when
    execution in the kernel began.

    All time prior to kernel entry must be charged to the SC that was
    current prior to kernel entry and all time after kernel exit must be
    charged to the SC that is current after the kernel exits. The cost of
    each duration between the entry and exits must be charged to the SC
    for which the kernel performed work. For durations associated with
    system calls or faults, the time is charged to the SC that was current
    on kernel entry. For durations associated with the release of a task,
    the released task is charged the cost of the entry. For durations
    associated with the delivery of an IRQ handled at user-level, the IRQ
    task is charged the cost of the entry.

    For IPIs, we only consider the case where an operation on a separate
    core, such as the signalling of a notification, releases the job of a
    task blocked on the core that receives the IPI where that task is at a
    higher priority than the task executing on that core. IPIs may occur in
    other situations, however almost all of these are for tasks that are not
    scheduled to consume time on the given core and so cannot be performed
    without violating timing analysis. Resolving this would require
    explicitly scheduling these operations as tasks and enforcing bounds on
    their occurrence.

    An alternative approach to determining kernel exit time is to assume a
    worst case cost of kernel execution between the read of a timestamp at
    kernel entry or preemption and kernel exit as the current timestamp is
    updated at every point where a kernel operation could be preempted if an
    interrupt has not been delivered, however the kernel execution time
    after this point is far more varied and would require a much more
    pessimistic overestimate of kernel execution time.

.. This seems like more explanation of the model so far...

.. What is the particular issue?

.. What is the effect of the particular issue in terms of the analysis?

.. What is the proposed solution?

.. Improving the manner in which execution time is bounded

.. Avoid accumulation of any error in implementation

..
    Bounding IRQ arrival
    --------------------

    To ensure that we charge all kernel execution time spent to accept an
    interrupt request (IRQ) to a task that can be considered in any
    scheduling analysis, we model each IRQ as its own task. When that task
    does not have available budget, we must mask the IRQ and unmask the IRQ
    when budget for the task becomes available.

    Rather than assigning a priority to each IRQ that can be delivered, we
    treat IRQs as all being tasks that have the same priority that is higher
    than the priority of any non-IRQ task. This approach is taken to avoid
    adding overheads related to masking and unmasking interrupts as
    priority of the highest released task changes. With this approach, we
    only unmask IRQs a when they exhaust their budget and unmask them once
    they regain budget.

    As all IRQs operate with the same priority, for correct analysis in a
    deadline-monotonic (DM) schedule, they would all require the same
    relative deadline, although the minimum inter-arrival times could
    differ. For any tasks that depend on IRQs for activation, the relative
    deadline of the IRQ tasks would need to be considered as part of the
    overall latency for responding to IRQs.

.. What is the particular issue?

.. What is the effect of the particular issue in terms of the analysis?

.. What is the proposed solution?

.. Model IRQs as a thread

.. Models IRQs *synchronously*!?

    * Call an IRQ to unmask it
    * IRQ responds when it is delivered
    * Donates the reservation to the IRQ?
    * Prevents the handler from accepting other requests or signals

Bounding priority inversion
---------------------------

When a task raises its priority, it must still be charged for all time
consumed at a higher priority. With the immediate priority ceiling
protocol (IPCP), a task operates at the highest priority of all acquired
resources, raising its priority on access and lowering its priority on
release. In seL4, we model mutually exclusive resources as threads. When
a task accesses a resource, execution switches to the thread of the
resource with the resource thread consuming time from the SC of the
task. This provides the ability for operations on a resource to operate
in a private virtual address space, such that only the IPC interface
provided by the resource can be used to access that resource.

The current model of seL4 assigns priorities to threads. When one thread
performs a synchronous IPC to another and that thread does not have a
bound SC, the SC of the calling thread is *donated* to the receiving
thread. The thread that receives the SC executes at its own priority
under the bandwidth constraints of that SC. When that thread later
replies to the calling thread, the donated SC is returned.

SCs can also be bound to asynchronous IPC objects (seL4 *notification*
objects). When a thread with no bound SC receives a notification from an
asynchronous IPC object with an SC, that SC is donated to the thread.
The SC is later returned when that SC performs a blocking receive
operation. This allows a single thread to act both as a resource,
receiving synchronous requests from lower-priority tasks, as well as an
explicit task at the same priority level. This may be useful if the task
implements a driver service that may also communicate with an external
device asynchronously and ensures that all operations on that resource
are atomic.

seL4 also allows the holder of a capability to a thread to change that
thread's priority and it's maximum controlled priority (MCP). In this
case, a capability to another thread provides an upper bound on the
newly configured priority and MCP as neither can be configured greater
than the MCP of the second thread.

This implementation effectively emulates *thread migration*, where a
single entity in the scheduler is able to execute across multiple
protection domains. This allows for a protection domain to encapsulate
access to certain system resources in a particular virtual address space
and the implementation of certain routines or services for accessing
those services. This has the advantage that the correct protocols
required to correctly access the state and resources of a protection
domain are always used as only the implementation of the routines within
the protection domain can operate on those resources. A task to execute
routines across multiple protection domains without requiring
synchronised communication to separately scheduled entity in the
scheduler that executes within that protection domain.

The fundamental issue presented by this implementation is that
implementing resource access, i.e. the ability for a task to raise its
priority to access a resource, is conflated with this emulation of
thread migration. This is achieved by configuring priorities as part of
thread object rather than as part of the scheduling context, allowing a
task to raise its priority *only* when it is bound by the same
scheduling context.

To ensure that tighter bounds are enforced when a task accesses a
resource, we must not allow the scheduling context of that to be
transferred in in its entirety to that resource, as this would not
enforce the necessary bounds on execution time for access to that
resource. Instead, we will separate these two concerns by ensuring that
priority is configured directly on the scheduling context and by
bounding the scheduling of accesses to resources by scheduling contexts
representing those resources. We will still allow this model of thread
migration, by allowing a task to pass its scheduling context to a task
with no scheduling context, as the entirety of the scheduling bounds are
now configured on the scheduling context.

Rather than using TCBs to provide the authority to set the priority of a
scheduling context, the scheduling control capability is used as
it would also be used to configure the other scheduling parameters of
any SC. Each scheduling control capability is assigned a badge of the
highest priority it can assign and can be used to mint a copy with an
equal or lower priority.

As the bounds for resource accesses must be stronger, we introduce a new
kind of scheduling context, a *resource scheduling context* (RSC).
Unlike SCs used to represent tasks, a RSC only receives budget via a
donation mechanism and never as the result of a job release. A RSC is
also configured with a maximum budget which can be set to the minimum
blocking time of all tasks at an equal or lower priority.

When time is donated to an RSC, the SC of the task performing the access
is also linked to the RSC. When nested accesses occur, a linked list is
formed between RSCs. When an SC donates time to an RSC, the donated
budget is set for the RSC. When a RSC donates time to another RSC, the
budget is deducted from the source RSC and returned when a matching
reply occurs. We do not allow the donation of budget to an RSC with a
priority lower than that of the SC that originally donated the budget.
Doing so would lead that task to be preempted by lower priority tasks,
which in turn can transitively interfere with the tasks at a lower
priority that is configured for the SC.

.. figure:: ./image/sc-send-rsc.eps
    :width: 10cm

    A task with a SC sending to a blocked task with a RSC

    When a task with a SC performs a blocking send to a task with a RSC,
    the RSC is linked to the SC and is given the minimum of the
    available budget in the SC and the RSC's configured maximum budget
    as its available budget.

.. figure:: ./image/sc-reply-rsc.eps
    :width: 10cm

    A task with a RSC replying to the task bound to the SC from which
    budget was originally donated

    When a task with a RSC performs any send to a task with a SC to
    which it is linked, the SC and RSC are unlinked, the RSC is unlinked
    from any other RSC, and the budget of the RSC is set to 0.

.. figure:: ./image/rsc-send-rsc.eps
    :width: 10cm

    A task with a RSC sending to a blocked task with a RSC

    When a task with an RSC performs a blocking send to another task
    with an unlinked RSC, the two are linked, the SC is unlinked and
    linked to the receiving RSC; pushing an RSC onto a linked list of
    RSCs. The receiving RSC is given the minimum of the sender's budget
    and its own configured maximum as its available budget with any
    remaining budget being left in the sending RSC.

.. figure:: ./image/rsc-nbsend-rsc.eps
    :width: 10cm

    A task with a RSC performing a non-blocking send to a blocked task
    with a RSC

    When a task with an RSC performs a non-blocking send to another task
    with an unlinked RSC, the SC is unlinked and linked to the receiving
    RSC and any link to the sending RSC is moved to the receiving RSC;
    swapping the head of the linked list of RSCs. The receiving RSC is
    given the minimum of the sender's budget and its own configured
    maximum as its available budget and the sending RSC has its budget
    set to 0.

.. figure:: ./image/rsc-reply-rsc.eps
    :width: 10cm

    A task with a RSC sending to the task bound to the previous RSC in
    the list of RSCs

    When a task with an RSC performs a send to the task with the
    previous RSC in the list, the SC is unlinked and linked to the
    previous RSC and the RSCs are unlinked from each other. This
    effectively pops the the end off of the linked list of RSCs. The
    sender's available budget is added back to that of the receiver and
    the sender's budget is then set to 0.

If a task with an RSC blocks in a manner that does not donate, the SC
loses all available budget and the SC is unlinked. This ensure that the
task with the RSC can only later continue execution when donated budget
from a running task. When a task with an RSC is unblocked while in a
queue of RSCs, it is unlinked from that queue and any budget it had
retained is returned to the previous RSC.

An advantage to this approach is that timing guarantees of the system
now only depend on the set of scheduling contexts that exist, rather
than depending on the ways in which they can be assigned to and passed
between threads. Further, the ability to alter the guarantees at any
particular priority only depends on the components with a scheduling
control capability with an equal or greater maximum configurable
priority. This makes it substantially easier to ensure the timing
properties of any system built with seL4 whilst still allowing
soft realtime and non-realtime tasks to be configured independently at
lower priority levels with reduced timing guarantees.

Given the above changes of introducing RSCs, bounding budget donated to
RSCs, tracing the SC associated with donated budget, and utilising the
scheduling control capability to assign priority directly to SCs and
RSCs, we can, with minimal effort, ensure that a task never lowers its
priority and never executes with a raised priority for longer a bound
specified for a given priority level.

..
    We model shared resources using seL4 threads with no bound scheduling
    context (SC) with a configured priority equal to the ceiling priority of
    all of their clients. When a client performs a synchronous call to the
    endpoint on which the resource thread is listening, control is
    transferred to the resource thread and any execution time for that
    thread is charged to the donated SC. When the resource thread replies to
    the calling thread, the SC is returned.

    seL4 does not presently bound the execution time of a thread without an
    SC beyond the available execution time of any donated SC. This can lead
    to a resource thread proceeding to execute with the scheduling
    constraints of any of its clients after a donation, completely
    invalidating the interference assumptions of any task with a configured
    priority below that of the resource thread. To ensure that any priority
    inversion is bounded, the maximum execution time between the donation
    and return of an SC is bounded for all resource threads.

    We restrict the amount of time available via donation by reducing any
    available budget when an SC is donated and by returning any deducted
    budget upon reply. We also mark an SC when it is first donated and
    unmark it when its first deducted time is returned. When a replenishment
    becomes available for a marked SC, that amount of time is not made
    immediately available and is instead made available when that SC returns
    to the original thread. When a marked SC exhausts available budget, it
    faults or becomes inactive and cannot execute again until it has been
    explicitly rebound to a thread. These restrictions ensure that only the
    configured bound on budget of a resource thread can be consumed by that
    thread for each call from a client, effectively bounding the duration of
    priority inversions for accesses to that resource.

    To ensure that a resource thread can rely on sufficient budget being
    available when acting on behalf of a client, we also only permit the
    call to the resource thread to occur once the client has at least the
    configured bound on budget for the resource thread. If a client attempts
    a call to a resource thread with insufficient budget, the client is
    faulted or suspended until it would have sufficient budget.

    Whilst this model is sufficient for single-core PCP, this model will
    likely not readily extend to shared resources in multicore systems which
    require that a task of the highest priority progresses even when all
    such tasks may be waiting on resources being accessed by tasks on other
    cores. Without some mechanism to migrate execution between all cores
    contending for resource as the highest released priority changes on each
    core, we cannot consider resources servers with clients across cores in
    our time demand analysis.

.. What is the particular issue?

.. What is the effect of the particular issue in terms of the analysis?

.. What is the proposed solution?


.. takeaway paragraph - approach

Implementation
==============

.. This section is the detail of how the model is implemented with
   changes to seL4.

To implement our model we must make several modifications to the seL4
kernel, particularly to its mechanisms for time keeping, charging time,
inter-process communication (IPC), and managing IRQs.

Sporadic servers
----------------

The current implementation of a *scheduling context* (SC) consists of a
bounded list of refills and a set of configuration parameters including
the SCs period, assigned CPU core, and references to other objects. When
an SC is configured, the period and core are set and a single refill
with the SCs full budget and a release time of the instant of
configuration is created as the only element in the list. The available
budget of an SC is the total budget in all refills with a release time
before the current time. The kernel uses a separate counter tracking
time consumed for the current SC. When the SC currently executing
changes, the consumed time is *charged* to the current SC and the next
SC is *released*. The charged time is deducted from the first refill in
the list and added one period after that refills release time. When an
SC is released, all refills with a release time before the time of the
SC's release are delayed and merged into a single refill with a release
time of the instant the actual release occurred.

If a SC does not have a refill with a release time before the current
time, it is placed in the release queue, which is an queue of threads
ordered by the release time of the first refill in their SC. When the
current time is no less than the release time of the first refill of an
SC in the release queue, that SC is removed from this queue.

The implementation effectively treats each change of an SC as release of
a task, including changes due to the execution of a higher priority task
in favour of a lower priority task. To change this implementation such
that it models sporadic server :cite:`Sprunt_SL_89`, we only need to
change the times at which an SC is released. Rather than releasing on
every change of the current SC, we only release an SC at the points
where we want to model the release of a job or group of jobs for the
task of that SC. As described in
:ref:`modelling-tasks-with-scheduling-contexts`, this is any instance
where the thread bound to the SC of a task is manually resumed,
unblocked from an IPC object, or where an unblocked task's first refill
becomes available.

..
    To change the current implementation from enforcing a sliding window
    constraint to implementing the weaker sporadic server constraint
    described by  we only need to modify the time at
    which the availble time and replenishments are all delayed to be
    released at the current time. The existing implementation, which
    enforces a sliding window constraint on execution, is based on
    the sporadic server implementation by :citet:`Stanovic_BWH_10` but
    applies the delay at any point a task is selected to execute as the
    current task. To achieve an implementation of the sporadic server model
    we instead apply this operation at any point where we consider a task to
    have been released. In terms of the seL4 scheduler, this is any point
    where a *scheduling context* (SC) that is not configured and associated
    with a *thread control block* (TCB) in a running state becomes
    configured and associated with a TCB that is in the running state,
    either by change of state in the associated TCB, configuration of the
    SC, or in a TCB becoming attached to the SC. This can occur whenever an
    blocked thread with an attached SC becomes unblocked or donates its SC
    to an unblocked thread, when a notification object donates an SC to a
    thread, when a TCB is directly resumed, when a SC is configured, or when
    a SC is explicitly linked to a TCB.

.. How did we change the implementation of Scheduling Contexts in seL4
   to implement Sporadic Server rather than Sliding Window

Correct and precise time attribution
------------------------------------

Our timing analysis assumes that all execution for a task is bounded by
that tasks assumed worst-case execution time (WCET) and its minimum
inter-arrival time. As we enforce these bounds by charging budget to a
*scheduling context* (SC) that represents the task, we must ensure that
only the execution related to that task is charged to the SC of that
task. All user-level execution time is considered part of that task's
execution. Not all kernel execution time that occurs while a given SC is
current is part of that task's execution. As such, we require mechanisms
to determine the duration of any kernel entry and to charge that time
to the SC of the task that the timing analysis assumed bounded that
execution time.

The current seL4 implementation only reads the scheduling timestamp once
per entry. Whichever SC is current on entry is charged all time prior to
the timestamp and whichever SC is current on exit is charged all time
after the timestamp. To enable us to specifically charge the time of the
kernel entry itself to a particular SC, we require knowing both the time
of entry into the kernel and the time of exit. Both times need to be
known at the point where the execution time before the kernel entry and
the execution time of the kernel entry itself will be charged to an SC.

Determining the time of entry is easiest done soon after entry,
preferably a consistent time after the last user-level instruction is
executed. At this point we can read the timestamp and subtract some
over-estimate of the worst-case time to get from user-level to reading
the timestamp. Determining the time of exit should similarly occur a
consistent time before the next user-level instruction is executed. The
kernel implementation generally charges time to scheduling contexts as
the last operation before returning to user-level. This is already an
optimal point in the kernel entry to read the timestamp and add some
overestimate for the worst case time between reading the timestamp and
user-level execution resuming.

The difference between the estimated entry and exit will be an
overestimate of the actual time spent in the kernel. If there is a bound
on this execution time, then this can be accounted for in the timing
analysis. The bound on such execution times depends on what capabilities
are available to a task as it executes with some capabilities allowing a
task to execute for longer periods in the kernel. The bound on these
durations also impacts the blocking time of higher-priority tasks.

When the kernel is entered due to a system call or user-level exception,
the kernel entry duration is charged to the SC that is current on entry.
Were the timestamp read on entry only used for charging time to the
current SC, we could avoid reading it as the both the time before the
kernel entry and the time between the entry and exit is charged to the
same SC. The timestamp read upon entry is used for more than just
charging time, it is also used determine whether the SC has sufficient
budget to complete a kernel operation and to determine if any SCs in the
release queue can be removed. As such, this timestamp read cannot
actually be avoided.

When the kernel entry is due to a preemption, such as when a SC waiting
for the release of a refill can once again run, the kernel entry is
charged to the released SC. If this is the same as the SC that is
current when the kernel exits, i.e., it has preempted the task that was
running when the kernel entered, then all time after kernel entry is
charged to the released SC. In this case, we can avoid reading the
timestamp before exiting the kernel.

Another case where kernel entries occur is in response to *interrupt
requests* (IRQs) from external devices. These kernel entries cannot be
guaranteed to be related to the currently executing task, and in general
are not. These kernel entries must be charged to SCs that are associated
with the IRQs themselves. In order to associate IRQs with SCs, we allow
SCs to be bound to IRQs using an IRQ handler capability. The SC then
bounds when interrupts can be delivered and is charged for the kernel
entries associated with that IRQ. When the SC associated with an IRQ has
no available budget, that IRQ is masked until the next refill and the SC
is added to the release queue. This allows a bound on IRQ delivery to be
configured via the SC bound to that IRQ. To facilitate the presence of
IRQ-bound SCs in the release queue, we change it to be a queue of
scheduling contexts rather than a queue of thread control blocks (TCBs).

..
    If a kernel entry is explicit, i.e. as system call, or the result of a
    user-level exception, then we assume this is part of the task modelled
    by the current SC and so can be charged to the current SC.

    We model all user-level execution while an SC is the current SC to
    be part of that task's execution. We also assume any explicit kernel
    entries, i.e. system calls, to be part of that task's execution. If
    there are exceptions produced by user-level code, these too are
    considered part of the current task's execution.

    We assume that any
    kernel entry 

    To ensure we charge all kernel time to the SC of the task for which that
    work was performed, we must make an overestimate of the overall time of
    the entirety of every kernel entry and subdivide it into portions that
    are attributable to different tasks. This requires a means of
    determining an appropriate start time, end time, and instant between
    each division such that no task is charged the cost of an entry into the
    kernel that it did not trigger.

    To estimate the time of entry into the kernel, we take the worst case
    for the time between the last instruction of user-level execution and
    the reading of the timestamp of all entry paths, i.e., any system call
    entry handlers, fault entry handlers, and interrupt entry handlers, and
    deduct at least this amount in addition to any access latency for the
    timestamp from the timestamp read. This time is read on all entries into
    the kernel as we do not know at this point whether the timestamp is
    necessary and the only case where it is not required is when the
    currently executing task has exhausted its available budget.

    To estimate the time between two consecutive kernel durations, i.e.,
    when point at which the task for which the work performed by the kernel
    changes, we read the timestamp and deduct the worst-case assumed access
    latency. When this occurs the time is charged to the associated SC
    immediately, but the time taken to charge that time is considered part
    of the subsequent duration. This occurs for each IPI that is handled
    before acquiring the kernel lock, the number of which is bounded by
    the number of kernel nodes in the system, and whenever a long-running
    system call is preempted by an interrupt.

    To estimate the time at which user-level continues execution, we read a
    timestamp at the end of the kernel entry whenever the end estimate would
    be required. This is any case where the kernel execution time is not
    charged to the same SC as execution time after the kernel exits. We then
    add an overestimate of the worst-case time between the timestamp being
    read and user-level resuming execution. This should be fairly consistent
    as there is little variance in the code path after this point. In order
    to charge the time for the kernel entry at this point, the kernel tracks
    a kernel duration SC throughout execution. For a system call or fault,
    this is set to the SC that was current on entry. For a preemption
    releasing a SC running at a higher-priority, this is set to the released
    SC. If the entry was for an interrupt or if a system call was preempted
    by an interrupt, the SC is set to that of the interrupt task.

.. Set timers with correct offsets

.. Overestimate entry time

..
    Bounded IRQ arrival
    -------------------

    To bind IRQs to scheduling contexts, we can simply provide each IRQ with
    a capability to a SC in the same manner that they are provided a
    capability to a notification and by adding an IRQ field to each SC to
    indicate which IRQ has been bound to that SC, only allowing an SC to be
    bound to a single IRQ at any time. Although it may not make sense in the
    real-time contexts we consider in this project, we do not prevent a SC
    from being bound to both a thread control block (TCB) and an IRQ at the
    same time. While this may not produce behavior expected of a task in a
    deadline-monotonic fixed-priority schedule, as the time reservation
    would alternate between the IRQ priority and the priority of the bound
    TCB, it can reduce the cost of charging preemption time when IRQ
    delivery leads to an immediate preemption and still provides a useful
    rate-limiting mechanism for IRQs in non real-time systems by avoiding
    the cost of charging the kernel time of the IRQ separately.

    Enabling a SC to be scheduled without a bound TCB requires more complex
    changes to the seL4 kernel as the queue of SCs that will not have
    available time until some point in the future is actually constructed
    out of a linked list in the bound TCBs as only SCs with bound TCBs can
    be charged for time in the current kernel. The most obvious resolution
    is to move the queue structure from the TCBs into the SCs, however to
    reduce implementation complexity and change to the existing kernel
    implementation we will instead modify the scheduling queues to queue
    both TCBs and IRQ nodes with a static linked-list node for each IRQ. As
    these nodes will only ever be enqueued into the queue of threads without
    sufficient execution time, we only need to consider the potential for
    these IRQ nodes to be dequeued when accessing elements from this queue
    despite the same queue nodes in TCBs being used for the runnable queues
    at each priority level.

    When the SC for an IRQ exhausts its budget, that IRQ is masked and the
    queue node is inserted into to the queue of tasks without sufficient
    budget. When that node is later removed from the queue as time is
    replenished for its SC, the IRQ is then unmasked. An IRQ is masked
    whenever it has not attached SC.

Bounding priority inversion
---------------------------

To allow tasks to access resources at an increased priority in
accordance with the *immediate priority ceiling protocol* (IPCP), we
must provide a way for higher priority execution to be attributed to a
task in a manner that is bounded by the blocking time of all tasks
between the baseline priority of the task and the priority of the
resource accessed.

The current seL4 implementation allows the *scheduling context* (SC) of
a task to be used indefinitely at the priority of a resource that it
accesses, effectively placing that task at that priority.

Rather than allow the resource to execute using the SC of the task, we
assign the resource a *resource scheduling context* (RSC). A resource SC
only executes on budget donated from a SC, either directly or via
another RSC. A RSC is also configured with an upper bound on the budget
that can be donated. When a RSC has donated budget, it is associated
with the SC from which the budget was originally donated and added to a
list of RSC that have performed nested donations. Any execution time
that would be charged to a RSC is deducted from the RSC's available
budget and charged to the associated SC. If the thread associated with
the SC resumes running and is associated with a RSC, that RSC is
disassociated and looses all available budget.

.. Never donate budget to a RSC with a priority below the original SC

.. The total budget available after donating to a priority at or above p
   is no greater than the bound on the budget of the RSC with priority p

   Passing budget to SCs other than by call/reply makes this whole thing
   substantially more complicated and I'm not convinced
   NBSendRecv/NBSendWait ever made sense as donating syscalls.

If a thread associated with a RSC blocks without donating to another
RSC or yields, it looses all available budget and is disassociated
from the SC that donated the budget. If the thread blocks for a
synchronous IPC with another RSC, budget up to the bound of the receiver
is donated and the associated SC is transferred. Any budget not donated
is kept in the RSC blocked waiting for a reply. When the receiving RSC
later responds, any unused budget is returned and the associated SC is
transferred back so long the receiving RSC has not been used to receive
more donated budget. If a RSC or SC to an RSC at a lower priority than
the SC from which budget is originally donated, the SC is disassociated
and all budget is lost.

This ensures that once a resource thread suspends, execution for that
RSC can only continue if it is invoked by a task at the highest runnable
priority, as is required by IPCP, instead of being able to resume
execution when a lower-priority task would receive a new job release.

To ensure that a task can never be preempted by lower-priority tasks,
i.e., that it lowers its priority, we never allow a SC to donate budget
to a RSC executing at a lower priority than the SC as the lower-priority
resource could then be preempted by a task that was not considered for
the response time of the SC that donated the time.

To ensure that a task only ever executes at the priority assumed by the
scheduling logic, i.e. its base priority or the priorities of the
resources that it accesses, we configure the priority of tasks and
resources directly on their SCs and RSCs. This has the benefit of
ensuring that the timing analysis holds based only on the knowledge of
which configured SCs and RSCs exist in the system and does not depend on
the SCs or RSCs being bound to particular threads with the correct
priority. To enable delegated configuration of SCs and RSCs at
priorities below that of all tasks and resources with bounded response
times, we allow the scheduling control capability to be minted with a
badge denoting the maximum priority it can configure. The minted
scheduling control capability can only have a maximum configured
priority no greater than that of the source capability.

..
    To implement a mechanism of restricted time donation to passive servers
    we introduce a new kind of scheduling context (SC), a resource
    scheduling context (RSC). A resource scheduling context has no
    configured period or budget, but instead has a configured capacity. This
    bounds the amount of time that can be transferred to the RSC. Regular
    SCs are also extended with a donated reserve. When a task's SC donates
    time to a resource SC, the donated time is tracked in the donated
    reserve. When a thread executing with a RSC replies to a thread with a
    task SC, any remaining time is returned to that task's available supply
    and the difference between the returned amount and the amount in the
    donated reserve is scheduled in a future replenishment.

    If a resource thread exhausts the budget in its RSC it stops and
    triggers a temporal fault. If the thread suspends in a manner that
    does not return remaining time previous consumer of the time, the time
    is considered entirely consumed and that task will not continue
    executing unless it can be donated more budget.

    Given this mechanism essentially requires a 1:1 relationship between
    threads and some form of SC, either a task SC or a RSC, a useful
    extension to this implementation would be to move all scheduling
    parameters into the SCs, including priority and the scheduling queues.
    This would ease the implementation of IRQ task scheduling and move the
    control of task execution priority to the same component responsible for
    configuring all other scheduling state and enforcing the assumptions of
    the configured task set, removing it from any component that may require
    access to a TCB to recover that TCB from faults but may not be trusted
    to correctly maintain the associated scheduling configuration.

    Separating these concerns with this mechanism and enforcing this
    scheduling behaviour also prevents any task from forcefully lowering its
    priority to accumulate available budget without being forced to consume
    it.

.. Restrict time donation

.. This will absolutely destroy the fastpath time.

.. Current SCs make no sense for MCS, priority should be in the control
   of the scheduler, not the fault handler.

.. Two options:

   - store donated time in endpoints:
       - Ugly
       - Inelegant
       - Very difficult to recover of time is exhausted or a fault occurs.
       - Slow fastpath for any task with bounded priority inversion
   - Add resource SCs
       - Every task requires some SC
       - Priorities on SCs rather than on threads.
       - Bandwidth donation!
       - SCs deduct time the is donated and add unused time when
         returned
       - If an SC is resumed by means other than reply, all donated time
         is assumed to have been consumed.
       - If a resource SC blocks, all donated time is assumed to have
         been consumed (essentially, they can only block to reply).
       - Resource SCs form a chain of donated time (rather than via
         reply objects).
       - A resource SC causes a temporal fault and time is exhausted
       - If a SC in a donation chain has the chain broken by any means
         other than a reply, the next link in the chain triggers a
         temporal fault.
       - Lose full bandwidth donation and current optimal fastpath
       - Call an SC to resume?
       - Make TCBs, SCs, Reply objects, and Endpoints the same thing
       - Get rid of notification objects.


.. Rather than implement a model that generalises well and reflects the
   way this should work. We are going to implement the hackiest bullshit
   possible

.. Don't aim for something that could be extended for SMP, the solution
   we have is so far from that that any meaningful progress in that
   direction would likely need a redesign.


.. takeaway paragraph - implementation

Evaluation
==========

.. How will we determine that the approach works?

.. How can we show the response time of tasks? (Kernel logging)

..
    To demonstrate the efficacy of our approach we instrument the kernel to
    track and log the durations of time attributed to each scheduling
    context with that information being extracted and reported at user level
    at the end of each test. The attributed times are made in terms of the
    timestamp of the scheduler clock and so are only as accurate as that
    clock. To obtain an estimate of kernel time, we also log the cycle
    counter for the system at each kernel entry and exit, scaling the cycle
    counter by the fixed processor frequency. With this, we can obtain an
    estimate for the kernel and user-level execution time attributed to each
    SC and demonstrate when the time has been attributed to the appropriate
    task.

    Rather than attempt to implement user-level tasks with a known
    worst-case execution, we implement all tasks such that they consume the
    maximum available time in a tight loop and then demonstrate that the
    tasks never exceed the provided bound and are always provided sufficient
    execution time less the cost of job release and completion and any
    voluntary kernel entries. We then use the kernel logging facilities to
    log the job releases of each task and the points in time where budget is
    exhausted indicating the point at which a task with the assumed WCET
    would be complete in the worst case.

    The user-level time simply increments in a tight-loop and we measure
    loss of time in any task as a reduction in number of iterations
    performed in any task.

The tests here are performed on a Hardkernel ODroid C2 with an Amlogic
S905 SoC containing 4 ARM |reg| Cortex |reg| A53 cores running at 1.5GHz
and 2GiB of physical RAM. All threads were pinned to the first CPU core.

..
    Generating workloads
    --------------------

.. Use response time to generate workloads that should be schedulable

.. How do we generate a schedulable task set?

.. How do we show that the tasks are temporally isolated?

   All tasks meet deadlines when all tasks are consuming the maximal
   amount of time.

.. How do we show that tasks never exceed the analysed response time?

.. How do we introduce pseudo-random aperiodicity?

.. How do we introduce pseudo-random sporadic tasks?

.. Introduce a random blocking task that blocks for random durations of
   times and replies to clients with random cycle counts to spin until
   replying

.. Misbehaving & malicious tasks

.. Resource servers trusted only by their clients (well behaved)

.. Handle faults in resource servers to keep clients unblocked

Correctly charging preemption time
----------------------------------

As identified in :ref:`correct-attribution-of-execution-time`, one way
in which the execution time of the kernel can be mis-attributed is that
a running SC may be charged the cost of the kernel entry to switch to a
higher prior task when a job of that task is released.

This test uses a low priority periodic task and a set of high priority
periodic tasks that are all out of phase, each with a bound SC. The
lower priority SC has a minimum inter-arrival time of :math:`12500
\text{\textmu s}` and a bounded WCET of :math:`8332 \text{\textmu s}`.
Each high priority task has a minimum inter-arrival time of :math:`400
\text{\textmu s}` and a bounded budget of :math:`24 \text{\textmu s}`.
All tasks will perform a tight loop that increments a counter at
user-level while it runs.

As a greater number of high-priority tasks are added to the task set,
the number of iterations counted by the low-priority task is reduced.
This indicates that there is execution other than that of the low
priority task being attributed to that task's SC, specifically the
execution of the kernel switching to the higher priority tasks.

.. figure:: ./image/preempt-sporadic.eps
    :height: 6cm

    :label:`fig:preempt-sporadic` A pair of periodic tasks and the
    kernel execution time charged to those tasks.

    Dark regions of the execution trace indicate areas where a task is
    charged from preemptive kernel execution.  The low-priority periodic
    task expends some of its budget each time it is preempted, reducing
    the amount of budget available for user-level execution.


With the updated implementation, which charges such kernel execution to
the task that is released in such cases, the number of iterations
counted be the low-priority tasks remains effectively unchanged as the
cost of releasing higher-priority tasks is no longer charged to the SC
of the low-priority task.

.. figure:: ./image/preempt-sporadic-fixed.eps
    :height: 6cm

    A pair of periodic tasks with kernel execution time charged to the
    preempting task

    Diagram is as in :ref:`fig:preempt-sporadic`, except the cost of
    preemption is always charged to the high-priority task. The
    low-priority task no longer expends budget when preempted ensuring
    user-level execution always has same budget available.

.. figure:: ./image/graphs/correct-charge.low-count/low-period:12500.eps
    :height: 8cm

    The number of iterations counted by the low priority task.

    This is relative to the number of out of phase higher priority tasks
    that preempt the lower priority task. The *sporadic* dataset
    indicates the count when only the change implementing sporadic
    server is applied. The *correct-charge* dataset indicates the count
    when the preemption time is attributed to the SCs of the higher
    priority tasks.

..
    To demonstrate that the kernel precisely and correctly attributes kernel
    execution time, we configure a task that consumes all available time and
    determine the number of iterations that task can perform over a given
    duration. We then introduce a higher-priority sporadic task with control
    of a timer device that can self-suspend and resume at a high frequency
    preempting the existing low-priority task a large number of times.
    We show that the existing mechanisms used to charge consumed time to
    tasks can charge part of the cost of such preemptions to the lower
    priority task, reducing its available bandwidth. We then show that the
    mechanisms that overestimate the cost of kernel execution and ensure the
    cost of kernel execution is charged to the task for which they can be
    most readily controlled results in the total cost being attributed to
    the higher-priority task and that the cost is proportional to the
    frequency at which that task suspends and resumes.

    .. admonition:: To Do

       Set up test code as above

       Graphs / data:

        - Iteration count of lower-priority task in given window of time
        - Iteration count of lower-priority task with higher-priority task
          present at increasing frequency of preemption on mainline seL4
        - As above, but with updated charging mechanisms
        - Micorseconds charge to each SC at increasing frequency of
          preemption on mainline seL4
        - As above, but with updated charging mechanisms

        - Execution trace on mainline kernel
        - Execution trace on updated kernel

.. The existing kernel allows tasks to expend time that is charged to
   lower-priority tasks / kernel time expended on behalf of one task is
   charged to another

.. Show that the new kernel expends time to each task appropriately

.. Show that when a higher-priority task is introduced that can preempt
   a given task, the lower priority task loses available execution time

.. Show that with the changes in charging, the lower-priority task no
   longer loses execution time

.. Show that the existing kernel does not charge more than the
   configured time to the task and that time is correctly charged to the
   correct task

Bounded interrupt delivery
--------------------------

As identified in :ref:`correct-attribution-of-execution-time`, a second
way in which the execution time of the kernel can be mis-attributed is
that a running SC may be charged the cost of the kernel entry caused be
the delivery of an *interrupt request* (IRQ) from a device.

This test uses a low priority periodic task and a high priority sporadic
tasks controlling a pair of timer devices, each with a bound SC. The
lower priority SC has a minimum inter-arrival time of :math:`12500
\text{\textmu s}` and a bounded WCET of :math:`8332 \text{\textmu s}`.
The high priority task has a minimum inter-arrival time of :math:`500
\text{\textmu s}` and a bounded budget of :math:`240 \text{\textmu s}`,
but acts as a sporadic task. The timers are configured such that the
second arrives 120 degrees out of phase with the first, i.e., 1/3rd of a
period after the first.

The low task will perform a tight loop that increments a counter at
user-level while it runs. The timer task will configure both timers and
then block, waiting for the IRQ from the second of the two timers. The
IRQ for the first timer will be delivered when either the low-priority
task or no task is executing.

As the frequency of the timers increases, the number of iterations
counted by the low-priority task is reduced.  This indicates that there
is execution other than that of the low priority task being attributed
to that task's SC, specifically the execution of the kernel switching
receiving the IRQs and the kernel switching the released to the higher
priority task.

.. figure:: ./image/irq-sporadic.eps
    :height: 6cm

    :label:`fig:irq-sporadic` IRQs releasing a handler and preempting a
    low-priority task

    When an IRQ arrives that can wake a high priority task, that task is
    charged the cost of switching to that task. When an IRQ arrives and
    does not release a task, the current task is charged the cost of the
    kernel handling the IRQ.

With the updated implementation charging the released task for the
kernel entry used to switch tasks, the number of iterations counted by
the lower-priority task decreases by less with the increased timer
frequency. There is still a substantial loss in time spent in the loop
of the low-priority task as the SC of that task is still charged for the
cost of the kernel responding to IRQs that do not release the higher
priority task. It is only once we introduce the *resource scheduling
contexts* (RSCs) that we see the low-priority task execute the same
number of iterations regardless of the activity of the timer and
high-priority task.

.. figure:: ./image/irq-scs.eps
    :height: 6cm

    IRQs with assigned scheduling contexts

    As in :ref:`fig:irq-sporadic`, but IRQs can only be delivered when
    their associated SC has available budget. When IRQs do arrive, the
    SC for the IRQ is charged rather than any task that could be
    preempted.

.. figure:: ./image/graphs/irq-bounded.low-count/high-extra-refills:0/high-budget:240/low-period:12500/timer-both:True.eps
    :height: 8cm

    The number of iterations counted by the low priority task.

    This is relative to the frequency of the configured timers.  The
    *sporadic* dataset indicates the count when only the change
    implementing sporadic server is applied. The *correct-charge*
    dataset indicates the count when the preemption time is attributed
    to the SCs of the higher priority tasks. The *irq-bounded* dataset
    indicates the count when IRQs are assigned SCs that are charged for
    the kernel entry that responds to the IRQ.

..
    To demonstrate that the kernel bounds interrupt delivery attributes the
    costs of delivery to an appropriate task, we introduce a similar
    configuration as before. We show a task executing with a low priority
    and determine the number of iterations that task can perform over a
    given duration. We then introduce a higher-priority task with control of
    two timer devices with separate IRQs. Both timers are configured with
    the same frequency but offset by a third of the timer period. The higher
    priority task then waits on the later of the two IRQs such that the
    earlier IRQ is delivered when either the lower-priority task or the
    system idle task is executing. We then show that the cost of this
    interrupt entry is charged to the lower priority task, both with and
    without the changes demonstrated in the previous section. We then also
    show that when IRQs are required to be bound to an SC, that SC bounds
    the interrupt frequency and ensures that the cost of the IRQ entry is
    attributed to the bound SC.

    .. admonition:: To Do

       Set up test described above

       Graphs / data:

        - Iteration count of lower-priority task in given window of time
        - Iteration count of lower-priority task with higher-priority task
          present at increasing frequency of preemption on mainline seL4
        - As above, but with updated charging mechanisms
        - As above, but with IRQ SCs
        - Micorseconds charge to each SC at increasing frequency of
          preemption on mainline seL4
        - As above, but with updated charging mechanisms
        - As above, but with IRQ SCs

        - Execution trace on mainline kernel
        - Execution trace with fixed attribution and no IRQ SCs
        - Execution trace with fixed attribution and with IRQ SCs

.. Show that interrupts in the existing kernel can be configured to
   charge time to executing tasks

.. SHow that associating SCs with IRQs both bounds the delivery of
   interrupts and does not charge time to executing tasks.

.. Show that tasks always meet deadlines despite worst-case behavior of
   other tasks.

Bounded priority inversion
--------------------------

As identified in :ref:`bounding-priority-inversion`, we must ensure that
a lower priority task cannot access a resource for longer than the
blocking time of tasks with a higher priority than the task accessing
the resource and a lower priority that the resource itself. If we do not
enforce this bound, the response time assumed by the timing analysis
will be incorrect.

This test uses a low priority periodic task, a medium priority periodic
task, and a high priority resource. The lower priority SC has a minimum
inter-arrival time of :math:`12500 \text{\textmu s}`.  The medium
priority task has a minimum inter-arrival time of :math:`400
\text{\textmu s}`, a bounded budget of :math:`24 \text{\textmu s}`, and
a blocking time of :math:`50 \text{\textmu s}`.

The low task will call the resource in a tight loop. The resource will
then spin in a tight loop to exhaust all budget. When the budget of the
resource is exhausted, a fault handler for the resource thread will
reply to the low task and reset the resource. The medium task will also
spin in a tight loop. When the medium task exhausts its budget, a fault
handler for that thread will log the time at which it ran out of budget
as this is essentially the completion time of that job. The medium task
is then reset and continues at the release of the next job. At the end
of the test we subtract the release time of each job of the medium
task from that jobs completion time as recorded by the fault handler.

As the bounded WCET of the low-priority task increases the worst-case
observed response time of the medium task also increases. This is due to
the entire budget of the low-priority task being raised to the priority
of the resource. If the resource thread had no fault handler, it could
continue executing on the time for future jobs of the low-priority task,
effectively allowing that task to execute at a raised priority
indefinitely.

.. figure:: ./image/resource-sporadic.eps
    :height: 6cm

    :label:`fig:resource-sporadic` A pair of periodic tasks with a low
    priority task accessing a high priority resource

    When a low-priority task accesses a high-priority resource, its
    entire set of scheduling bounds are then applied at that higher
    priority. This allows the low priority task to preempt the
    high-priority task for its enitre WCET.

With the updated implementation, we assign the resource thread a
*resource scheduling context* (RSC) with a budget bound no greater than
the blocking time of the medium task. Whenever the low-priority thread
calls the resource, no more than the bounded amount of budget is
donated. As the budget of the low priority task increases, the
worst-case observed response time of the medium priority task remains
the same.

.. figure:: ./image/resource-sporadic-bounded.eps
    :height: 6cm

    A pair of periodic tasks with a low priority task accessing a
    high priority resource bounded by a RSC

    As in :ref:`fig:resource-sporadic`, but the resource is bounded by a
    RSC and is only donated available budget from the low-priority task
    up to the RSC's configured maximum budget.

.. figure:: ./image/graphs/shared-resource.high-response.eps
    :height: 8cm

    The worst case observed response time of the medium priority task.

    This is relative to the bounded WCET of the low priority task.  The
    *sporadic* dataset indicates the response time when only the change
    implementing sporadic server is applied. The *bounded-inversion*
    dataset indicates the response time when the resource is configured
    with a RSC with a bounded budget no more than the blocking time of
    the medium task.

..
    To demonstrate that the kernel bounds the duration of calls to shared
    resource servers and thus the duration of priority inversions where
    low-priority tasks access high-priority shared resource servers, we
    construct a system with a single task and show that it can execute with
    sufficient budget within the expected response time. We then introduce a
    resource server at a higher priority with a client at a lower priority.
    We show that despite the kernel enforcing execution bounds when no
    shared resource accesses occur, the kernel fails to bound share resource
    accesses and the response time of the high-priority task exceeds the
    analysed worst case response time. We then show that when the kernel
    correctly bounds the duration of calls to shared resource servers, tasks
    at lower priorities than those resource servers still observe a
    well-bounded response time when the analysis accounts for the bounded
    shared resource access.

.. Show that the current kernel does not enforce a bound on priority
   inversion and that any analysis places trust in any shared resourse
   server at a higher priority

.. Show that the adjusted kernel ensures that the priority inversion
   time from shared resource access is bounded removing inherent trust
   in such servers.

..
    Results
    -------

.. A great place to put some graphs

..
    Overheads
    ---------

.. How does each mechanism affect kernel performance?

   Where are new overheads introduced?

    - Memory size of kernel objects
    - Cost of call to passive server
    - Cost of call to active server
    - IRQ response time

   What are the existing overheads

   What are the overheads with the features available but not used

   What are the overheads with the features in use

..
    Utilisation
    -----------

.. Measure utilisation (expected maximum & actual)

.. Determine maximum worst-case utilisation / limit

.. takeaway paragraph - evaluation

Summary
-------

.. Summarise the evaluation

These test clearly show that the effect of the existing implementation,
even with the modifications to implement the sporadic server model, is
quite pronounced and poses a great challenge to predicting scheduling
behavior. Inaccuracies in how the implementation charges execution time
to SCs and accounts for kernel execution time can greatly reduce the
effective execution time of tasks within a system and the lack of
execution bound on resource accesses effectively eliminates the
assumption of the priority associated with any task. In summary, it
would be effectively impossible to produce a system with any guarantee
of a response time without thorough verification of every component in
the system.

The results of applying the changes proposed by this thesis demonstrate
their clear efficacy. By accurately attributing kernel execution time we
can remove the need to consider loss of usable budget by a task due to
preemption. By allowing a resource to be configured with a bound on
execution time of each access, we can ensure that the access to a
resource never exceed the blocking time of tasks at lower priorities,
regardless of the correctness of scheduling configuration of clients to
those resources.

These mechanisms allow us to build a system utilising rate-monotonic
scheduling and the immediate priority ceiling protocol and guarantee the
response time of the tasks within that system, down to some minimum
priority. These guarantees are provided only on the basis of the
scheduling contexts configured by tasks with access to a scheduling
control capability and do not depend on the implementation or
configuration of the rest of the system.

Future work
===========

seL4 is still far from being a suitable kernel for mixed-criticality or
hard-realtime systems. This project has outlined some changes that could
be made to resolve this, however there are still many issues that must
be resolved before this kernel would be an appropriate choice in this
domain, particularly when targeting multicore systems.

As seL4 is a formally verified, many of the mechanisms may not be
constructed in such a way as to be easily verified. Some consideration
would need to be given to implementations that are compatible with the
existing verification work of the kernel.

The systems discussed in this paper only considered those scheduled with
rate-monotonic and deadline-monotonic algorithms and the immediate
priority ceiling protocol. More work is needed to determine if the
policies enforced by this system are sufficiently general that they may
apply to other scheduling algorithms and resource access protocols.

Little consideration is given in this thesis to real-time systems
configured dynamically at run-time. Although the assumptions of this
paper do not include the systems in question to be configured
statically, more consideration should be given to the interactions
between mechanisms used to reconfigure real-time systems dynamically and
the guarantees provided by the scheduler.

The detailed effects of constructing system on multicore processing
hardware have not been considered in depth here. More work is needed to
determine how inter-processor interrupts (IPIs) used by the kernel can
interact with the scheduler's ability to maintain the execution
guarantees.

This thesis did not consider mutually exclusive resource access across
processing cores. Extending the IPC mechanisms from this thesis to apply
to such resource accesses would require further research work and
consideration of the assumptions such resource accesses introduce that
must be guaranteed by a multicore scheduler.

This thesis did not explore the ability to use the mechanisms discussed
to enable assigning priority to *interrupt requests* (IRQs).  This would
appear to follow naturally from the fact that IRQs would now require
bound scheduling contexts and that all scheduling contexts have a
configured priority. Implementing IRQ priorities in seL4 requires
further work.

While this thesis has demonstrated that seL4 can, with some
modification, be used as the basis of robust real-time systems with
string timing guarantees, there is still great opportunity to adapt
these mechanisms for even more general systems and more work is needed
to understand the interactions between the operating systems primitives
provided by the kernel and the guarantees that the kernel's scheduler
offers.

.. Dynamically configured realtime systems

.. multicore analysis

   - IPI costs and kernel entry bounding

   - Shared resources across cores

.. Avoiding preemption from equal and lower priority tasks

.. Lack of kernel WCET, which is worsened by the MCS implementation of
   IPC and scheduler queueing

..
    Formal verification
    -------------------

.. Verification at this point would be premature, to say the least

.. This shouldn't be verified until the model can be shown to address
   all the necessary concerns of the intended use cases

.. Want to extend the seL4 proofs to fromally verify the bounds placed
   on execution and interrupt delivery as well as sufficeint execution

..
    Alternate scheduling algorithms
    -------------------------------

.. Dynamic priority algorithms such as EDF

    * Priority implemented at user-level
    * Stack-based resource policy

.. takeaway paragraph - evaluation

Conclusion
==========

In this thesis we presented a set of modifications to the seL4
scheduling extensions for mixed criticality systems. The modifications
allow the scheduler to guarantee the assumptions made regarding
execution by common scheduling analysis techniques. We have demonstrated
that the modifications produce a scheduler that allows for simple
assumptions to be made regarding scheduling and timing behaviour such
that hard realtime and mixed criticality systems can be ensure
guaranteed response times of critical tasks with a minimal subset of
tasks requiring verification.

Although the changes proposed produce a set of useful scheduling
mechanism, further work is needed to determine a cohesive set of
operating system primitives that be offered by a formally verified
microkernel, particularly one that can benefit from modern
multiprocessor architectures.

.. What was the problem?

.. How did we solve it?

.. Were we successful in solving it?

.. With seL4 we can construct systems that are mathematically guaranteed
   to satisfy their real-time requirements

.. takeaway paragraph - conclusion

.. Aim for about 20k words?
